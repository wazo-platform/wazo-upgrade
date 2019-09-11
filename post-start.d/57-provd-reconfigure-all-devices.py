#!/usr/bin/env python3
# Copyright 2019 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

import argparse
import os
import requests
import sys
import time

from urllib3.exceptions import InsecureRequestWarning
from wazo_auth_client import Client as AuthClient
from wazo_provd_client import Client as ProvdClient
from wazo_provd_client.exceptions import ProvdError
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


def _wait_for_provd(provd_client):
    for _ in range(30):
        try:
            provd_client.params.list()
            return
        except ProvdError:
            return
        except requests.exceptions.ConnectionError:
            time.sleep(1.0)

    print('provd reconfigure all devices failed, could not connect to wazo-provd')
    sys.exit(2)


def reconfigure_all_devices():
    config = _load_config()
    provd_client = ProvdClient(**config['provd'])
    _wait_for_provd(provd_client)

    auth_client = AuthClient(**config['auth'])
    token = auth_client.token.new('wazo_user', expiration=5*60)
    provd_client.set_token(token['token'])

    devices = provd_client.devices.list(recurse=True)['devices']

    for device in devices:
        provd_client.devices.reconfigure(device['id'])
        provd_client.devices.synchronize(device['id'])


def main():
    args = parse_args()

    if not args.force:
        version_installed = os.getenv('XIVO_VERSION_INSTALLED')
        if version_installed >= '19.13':
            sys.exit(0)

    sentinel_file = '/var/lib/wazo-upgrade/57-provd-reconfigure-all-devices'
    if os.path.exists(sentinel_file):
        # migration already done
        sys.exit(1)

    reconfigure_all_devices()

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
