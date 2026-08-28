#!/usr/bin/env python3
# Copyright 2026 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

"""Rewrite wazo-dird favorites keyed on a confd user id to the user uuid.

The wazo source of wazo-dird now identifies contacts by the confd user uuid.
Favorites stored before that switch hold the confd user id and stop resolving
unless they are rewritten.

wazo-dird ships the migration as a view plugin that is disabled by default.
This script enables it through conf.d, calls it once, then removes the
configuration and restarts wazo-dird, so the endpoint is reachable only for
the duration of the migration.

A favorite of a user confd no longer knows cannot be rewritten, and wazo-dird
reads user uuids only once this has run, so the migration deletes it. Each one
is logged with its contact id.
"""

import argparse
import json
import logging
import os
import sys
import time
from collections.abc import Iterator
from contextlib import contextmanager
from subprocess import run
from typing import Any

import requests
from wazo_auth_client import Client as AuthClient
from xivo.chain_map import ChainMap
from xivo.config_helper import parse_config_file, read_config_file_hierarchy

# the bats suite points every absolute path into a fake root, like the shell
# scripts of this repository already do
_ROOT = os.getenv('WAZO_UPGRADE_ROOT', '')

SENTINEL = f'{_ROOT}/var/lib/wazo-upgrade/dird-favorite-uuid-migration'

_DEFAULT_CONFIG = {
    'config_file': f'{_ROOT}/etc/wazo-upgrade/config.yml',
    'auth': {'key_file': f'{_ROOT}/var/lib/wazo-auth-keys/wazo-upgrade-key.yml'},
    'dird': {'host': 'localhost', 'port': 9489, 'version': '0.1'},
}

_CONFIG_FILENAME = f'{_ROOT}/etc/wazo-dird/conf.d/999-wazo-favorite-migration.yml'
_CONFIG_FILE = '''\
enabled_plugins:
  views:
    favorite_migration: true
'''

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('dird-favorite-uuid-migration')


def load_config() -> Any:
    file_config = read_config_file_hierarchy(_DEFAULT_CONFIG)
    key_config = _load_key_file(ChainMap(file_config, _DEFAULT_CONFIG))
    return ChainMap(key_config, file_config, _DEFAULT_CONFIG)


def _load_key_file(config: Any) -> dict[str, Any]:
    key_file = parse_config_file(config['auth']['key_file'])
    return {
        'auth': {
            'username': key_file['service_id'],
            'password': key_file['service_key'],
        },
    }


def _wait_for_dird(dird_config: Any) -> None:
    url = 'http://{host}:{port}/{version}/status'.format(**dird_config)
    for _ in range(30):
        try:
            requests.get(url, timeout=1)
            return
        except (requests.exceptions.ConnectionError, requests.exceptions.Timeout):
            # a wazo-dird that hung on startup accepts the connection and
            # never answers, which only a timeout tells apart from a slow one
            time.sleep(1.0)

    logger.error('Could not connect to wazo-dird, aborting')
    sys.exit(2)


@contextmanager
def _migration_plugin(dird_config: Any) -> Iterator[None]:
    with open(_CONFIG_FILENAME, 'w') as f:
        f.write(_CONFIG_FILE)
    run(['systemctl', 'restart', 'wazo-dird'])
    _wait_for_dird(dird_config)

    try:
        yield
    finally:
        try:
            os.unlink(_CONFIG_FILENAME)
        except FileNotFoundError:
            pass
        run(['systemctl', 'restart', 'wazo-dird'])
        _wait_for_dird(dird_config)


def _log_report(report: dict[str, Any]) -> None:
    logger.info(
        '%s favorite(s) migrated, %s already migrated, %s deduplicated, '
        '%s dropped, %s source(s) failed',
        report['migrated'],
        report['already_migrated'],
        report['deduplicated'],
        report['dropped'],
        report['failed_sources'],
    )
    for source in report['sources']:
        for dropped in source['dropped']:
            # wazo-dird reads user uuids only from here on, so a favorite that
            # matches no confd user cannot be kept; log it to leave a trace
            logger.warning(
                '%s: favorite %s of user %s matches no confd user, deleted',
                source['source_name'],
                dropped['contact_id'],
                dropped['user_uuid'],
            )
        if source['error']:
            logger.error('%s: not migrated: %s', source['source_name'], source['error'])


def migrate_favorites() -> None:
    config = load_config()
    auth_client = AuthClient(**config['auth'])
    token = auth_client.token.new(expiration=5 * 60)['token']

    with _migration_plugin(config['dird']):
        url = 'http://{host}:{port}/{version}/favorite_migration'.format(
            **config['dird']
        )
        result = requests.post(url, headers={'X-Auth-Token': token})

        if result.status_code != 200:
            logger.error(
                'Migration failed, status-code %s: %s. '
                'Check /var/log/wazo-dird.log for more info',
                result.status_code,
                result.text,
            )
            sys.exit(2)

        report = json.loads(result.text)
        _log_report(report)

        if report['failed_sources']:
            logger.error(
                'Migration incomplete: some sources could not be reached, see above'
            )
            sys.exit(2)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        '-f',
        '--force',
        action='store_true',
        help='Run again even if the migration already ran. The migration is '
        'idempotent: favorites already keyed on a uuid are left untouched.',
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    if os.path.exists(SENTINEL) and not args.force:
        sys.exit(0)

    migrate_favorites()

    with open(SENTINEL, 'w'):
        pass


if __name__ == '__main__':
    main()
