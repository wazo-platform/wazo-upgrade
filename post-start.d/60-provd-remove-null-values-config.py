#!/usr/bin/env python3
# Copyright 2019 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

import argparse
import os
import requests
import subprocess
import sys
import time

from urllib3.exceptions import InsecureRequestWarning
from xivo_auth_client import Client as AuthClient
from wazo_provd_client import Client as ProvdClient
from xivo.chain_map import ChainMap
from xivo.config_helper import read_config_file_hierarchy, parse_config_file

_DEFAULT_CONFIG = {
    'config_file': '/etc/wazo-upgrade/config.yml',
    'auth': {
        'key_file': '/var/lib/wazo-auth-keys/wazo-upgrade-key.yml'
    }
}

requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)


def _load_config():
    file_config = read_config_file_hierarchy(_DEFAULT_CONFIG)
    key_config = _load_key_file(ChainMap(file_config, _DEFAULT_CONFIG))
    return ChainMap(key_config, file_config, _DEFAULT_CONFIG)


def _load_key_file(config):
    key_file = parse_config_file(config['auth']['key_file'])
    return {
        'auth': {'username': key_file['service_id'], 'password': key_file['service_key']},
    }


def _wait_for_provd(provd_config):
    url = 'https://{host}:{port}{prefix}/configure'.format(**provd_config)
    for _ in range(30):
        try:
            requests.get(url, verify=False)
            return
        except requests.exceptions.ConnectionError:
            time.sleep(1.0)

    print('provd config null values removal failed, could not connect to xivo-provd')
    sys.exit(2)


def _remove_null_value(config):
    if isinstance(config, list):
        return [_remove_null_value(x) for x in config]
    elif isinstance(config, dict):
        return {k: _remove_null_value(v) for k, v in config.items() if v is not None}
    else:
        return config


def remove_null_values():
    config = _load_config()
    _wait_for_provd(config['provd'])

    auth_client = AuthClient(**config['auth'])
    provd_client = ProvdClient(**config['provd'])
    token = auth_client.token.new('wazo_user', expiration=5*60)
    auth_client.set_token(token['token'])
    provd_client.set_token(token['token'])

    configs = provd_client.configs.list()['configs']

    for config in configs:
        provd_client.configs.update(_remove_null_value(config))

    subprocess.run(['systemctl', 'restart', 'xivo-provd'])


def main():
    args = parse_args()

    if not args.force:
        version_installed = os.getenv('XIVO_VERSION_INSTALLED')
        if version_installed >= '19.07':
            sys.exit(0)

    sentinel_file = '/var/lib/xivo-upgrade/60-provd-remove-null-values-config'
    if os.path.exists(sentinel_file):
        # migration already done
        sys.exit(1)

    remove_null_values()

    with open(sentinel_file, 'w'):
        pass


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '-f',
        '--force',
        action='store_true',
        help="Do not check the variable XIVO_VERSION_INSTALLED. Default: %(default)s",
    )
    return parser.parse_args()


if __name__ == '__main__':
    main()
