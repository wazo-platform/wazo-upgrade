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
is logged with its contact id. Favorites of a source whose tenant no longer
exists are deleted for the same reason and logged per source.
"""

import argparse
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

SENTINEL = '/var/lib/wazo-upgrade/dird-favorite-uuid-migration'

_DEFAULT_CONFIG = {
    'config_file': '/etc/wazo-upgrade/config.yml',
    'auth': {'key_file': '/var/lib/wazo-auth-keys/wazo-upgrade-key.yml'},
}

_CONFIG_FILENAME = '/etc/wazo-dird/conf.d/20-wazo-upgrade-favorite-migration.yml'
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


def _dird_url(dird_config: Any, resource: str) -> str:
    scheme = 'https' if dird_config['https'] else 'http'
    prefix = dird_config['prefix'] or ''
    return (
        f'{scheme}://{dird_config["host"]}:{dird_config["port"]}'
        f'{prefix}/{dird_config["version"]}/{resource}'
    )


def _wait_for_dird(dird_config: Any) -> None:
    url = _dird_url(dird_config, 'status')
    for i in range(1, 31):
        try:
            requests.get(url, timeout=1)
            return
        except (requests.exceptions.ConnectionError, requests.exceptions.Timeout):
            if i > 10:
                logger.warning(
                    'wazo-dird has not come back up since restart (attempt %d/30)', i
                )
            time.sleep(1.0)

    logger.error('Could not connect to wazo-dird, aborting')
    sys.exit(2)


@contextmanager
def _migration_plugin(dird_config: Any) -> Iterator[None]:
    with open(_CONFIG_FILENAME, 'w') as f:
        f.write(_CONFIG_FILE)
    try:
        run(['systemctl', 'restart', 'wazo-dird'])
        _wait_for_dird(dird_config)
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
        '%s dropped, %s source(s) of a deleted tenant, %s source(s) failed',
        report['migrated'],
        report['already_migrated'],
        report['deduplicated'],
        report['dropped'],
        report['orphan_sources'],
        report['failed_sources'],
    )
    for source in report['sources']:
        if source['tenant_deleted']:
            logger.warning(
                '%s: tenant no longer exists, %s favorite(s) deleted',
                source['source_name'],
                len(source['dropped']),
            )
            continue
        for dropped in source['dropped']:
            logger.warning(
                '%s: favorite (ID: %s) of user %s matches no confd user, deleted',
                source['source_name'],
                dropped['contact_id'],
                dropped['user_uuid'],
            )
        if source['error']:
            logger.error('%s: not migrated: %s', source['source_name'], source['error'])


def migrate_favorites() -> None:
    config = load_config()
    auth_client = AuthClient(**config['auth'])
    token = auth_client.token.new(expiration=60 * 60)['token']

    with _migration_plugin(config['dird']):
        url = _dird_url(config['dird'], 'favorite_migration')
        result = requests.post(url, headers={'X-Auth-Token': token})

        if result.status_code != 200:
            logger.error(
                'Migration failed, status-code %s: %s. '
                'Check /var/log/wazo-dird.log for more info',
                result.status_code,
                result.text,
            )
            sys.exit(2)

        report = result.json()
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
