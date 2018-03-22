#!/usr/bin/env python3
# Copyright 2018 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0+

import psycopg2
import os
import sys

from contextlib import closing
from xivo.chain_map import ChainMap
from xivo.config_helper import read_config_file_hierarchy, parse_config_file
from xivo_auth_client import Client as AuthClient

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


def _assign_users_to_tenants(auth_client, user_tenant_map):
    print('assigning users to tenants', end='')
    for user_uuid, tenant_uuid in user_tenant_map.items():
        _set_user_tenant(auth_client, user_uuid, tenant_uuid)
    print(' done')


def _get_user_tenant_map(cursor):
    print('fetching user tenant data', end=' ')
    qry = 'SELECT uuid, tenant_uuid FROM userfeatures'
    cursor.execute(qry)
    result = {row[0]: row[1] for row in cursor.fetchall()}
    print('done')
    return result


def _set_user_tenant(auth_client, user_uuid, tenant_uuid):
    # Set the tenant
    auth_client.tenants.add_user(tenant_uuid, user_uuid)

    # Remove any other previous associations
    all_user_tenants = {tenant['uuid'] for tenant in auth_client.users.get_tenants(user_uuid)['items']}
    all_user_tenants.discard(tenant_uuid)
    for uuid in all_user_tenants:
        auth_client.tenants.remove_user(uuid, user_uuid)

    print('.', end='')


def do_migration(config):
    auth_client = AuthClient(**config['auth'])
    token = auth_client.token.new('xivo_service', expiration=36000)['token']
    auth_client.set_token(token)

    with closing(psycopg2.connect(config['db_uri'])) as conn:
        cursor = conn.cursor()
        user_tenant_map = _get_user_tenant_map(cursor)

    _assign_users_to_tenants(auth_client, user_tenant_map)


def main():
    if not os.path.exists('/var/lib/xivo-upgrade/entity_tenant_association_migration'):
        print('03_entity_tenant_migration.py should be executed first')
        sys.exit(1)

    sentinel_file = '/var/lib/xivo-upgrade/tenant_synchronization'
    if os.path.exists(sentinel_file):
        sys.exit(1)

    config = _load_config()
    do_migration(config)

    with open(sentinel_file, 'w'):
        pass


if __name__ == '__main__':
    main()
