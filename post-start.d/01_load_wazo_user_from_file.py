#!/usr/bin/env python3
# Copyright 2017-2018 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0+

import json
import sys
import os
import urllib3

import requests

from xivo.chain_map import ChainMap
from xivo.config_helper import read_config_file_hierarchy, parse_config_file
from xivo_auth_client import Client as AuthClient

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

_DEFAULT_CONFIG = {
    'config_file': '/etc/wazo-upgrade/config.yml',
    'auth': {
        'key_file': '/var/lib/xivo-auth-keys/wazo-upgrade-key.yml'
    }
}


def _load_config():
    file_config = read_config_file_hierarchy(_DEFAULT_CONFIG)
    key_config = _load_key_file(ChainMap(file_config, _DEFAULT_CONFIG))
    return ChainMap(key_config, file_config, _DEFAULT_CONFIG)


def _load_key_file(config):
    key_file = parse_config_file(config['auth']['key_file'])
    return {'auth': {'username': key_file['service_id'],
                     'password': key_file['service_key']}}


def _create_user(auth_client, user):
    try:
        auth_client.users.new(**user)
    except requests.HTTPError as e:
        error = e.response.json() or {}
        if error.get('error_id') == 'invalid_data':
            if error.get('details', {}).get('email_address', {}).get('constraint_id') == 'email':
                user['email_address'] = None
                _create_user(auth_client, user)
                return
        if error.get('error_id') == 'conflict':
            if error.get('details', {}).get('uuid', {}).get('constraint_id') == 'unique':
                return
            elif error.get('details', {}).get('username', {}).get('constraint_id') == 'unique':
                return
            elif error.get('details', {}).get('email_address', {}).get('constraint_id') == 'unique':
                return
        raise


def _import_wazo_user(users):
    config = _load_config()
    auth_client = AuthClient(**config['auth'])
    token = auth_client.token.new('xivo_service', expiration=300)['token']
    auth_client.set_token(token)

    print('migrate users to wazo-auth', end='', flush=True)
    for user in users:
        _create_user(auth_client, user)
        print('.', end='', flush=True)
    print('\ndone')


def main():

    if os.getenv('XIVO_VERSION_INSTALLED') > '18.03':
        sys.exit(0)

    migration_file = '/var/lib/xivo-upgrade/migrate_xivo_user_to_wazo_user'
    if os.path.exists(migration_file):
        # migration already done
        sys.exit(0)

    user_file = '/var/lib/xivo-upgrade/xivo_user_dump.json'
    if not os.path.exists(user_file):
        print('xivo_user to wazo_user migration failed: File {} does not exist.'.format(user_file))
        sys.exit(-1)

    with open(user_file, 'r') as f:
        users = json.load(f)

    _import_wazo_user(users)

    with open(migration_file, 'w'):
        pass

    os.unlink(user_file)


if __name__ == '__main__':
    main()
