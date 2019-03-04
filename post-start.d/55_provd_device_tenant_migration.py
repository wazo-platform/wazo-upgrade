#!/usr/bin/env python3
# Copyright 2019 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

import argparse
import json
import os
import requests
import subprocess
import sys
import time

from requests.exceptions import HTTPError
from urllib3.exceptions import InsecureRequestWarning
from xivo_auth_client import Client as AuthClient
from xivo_confd_client import Client as ConfdClient
from xivo.chain_map import ChainMap
from xivo.config_helper import read_config_file_hierarchy, parse_config_file

_DEFAULT_CONFIG = {
    'config_file': '/etc/wazo-upgrade/config.yml',
    'auth': {
        'key_file': '/var/lib/wazo-auth-keys/wazo-upgrade-key.yml'
    }
}
PROVD_JSONDB_DEVICES_DIR = '/var/lib/xivo-provd/jsondb/devices'

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

    print('provd tenant migration failed, could not connect to xivo-provd')
    sys.exit(2)


def migrate_tenants():
    config = _load_config()

    _wait_for_provd(config['provd'])

    auth_client = AuthClient(**config['auth'])
    token = auth_client.token.new('wazo_user', expiration=5*60)
    auth_client.set_token(token['token'])
    confd = ConfdClient(token=token['token'], **config['confd'])

    master_tenant_uuid = token['metadata']['tenant_uuid']
    print('Master tenant UUID:', master_tenant_uuid)

    for dir_entry in os.scandir(PROVD_JSONDB_DEVICES_DIR):
        device_filename = dir_entry.path
        with open(device_filename, 'r') as device:
            try:
                device_content = json.load(device)
            except json.JSONDecodeError:
                print(device_filename, 'is not a valid JSON file. Skipping.')
                continue

            device_id = device_content['id']
            try:
                device_lines = confd.devices(device_id).list_lines()
            except HTTPError as e:
                if e.response.status_code == 404:
                    print(device_id, 'does not exist in confd. Skipping.')
                    continue
                raise
            line_tenant_uuid = master_tenant_uuid
            if device_lines['items']:
                first_line_id = device_lines['items'][0]['line_id']
                line_info = confd.lines.get(first_line_id)
                line_tenant_uuid = line_info['tenant_uuid']
            print('Device {} tenant_uuid will be set to {}'.format(device_id, line_tenant_uuid))
            device_content['tenant_uuid'] = line_tenant_uuid
        with open(device_filename, 'w') as device:
            json.dump(device_content, device)

    subprocess.run(['systemctl', 'restart', 'xivo-provd'])


def main():
    args = parse_args()

    if not args.force:
        version_installed = os.getenv('XIVO_VERSION_INSTALLED')
        if version_installed and version_installed > '19.04':
            sys.exit(0)

    sentinel_file = '/var/lib/xivo-upgrade/55_provd_device_tenant_migration'
    if os.path.exists(sentinel_file):
        # migration already done
        sys.exit(1)

    migrate_tenants()

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
