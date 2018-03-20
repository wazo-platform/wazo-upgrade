#!/usr/bin/env python3
# Copyright 2018 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0+

import psycopg2
import os
import sys

from contextlib import closing
from xivo_auth_client import Client as AuthClient
from xivo.chain_map import ChainMap
from xivo.config_helper import read_config_file_hierarchy, parse_config_file

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


def _associate_userfeatures_to_tenants(cursor, entity_tenant_map):
    qry = 'UPDATE userfeatures SET tenant_uuid=%s WHERE entityid=%s'
    for entityid, tenant_uuid in entity_tenant_map.items():
        cursor.execute(qry, (tenant_uuid, entityid))


def _create_all_tenants(cursor, entity_tenant_map):
    existing_tenants = _get_existing_tenants(cursor)
    tenant_uuids = set(entity_tenant_map.values())
    missing_tenants = tenant_uuids - existing_tenants

    if not missing_tenants:
        return

    print('inserting tenants', missing_tenants)
    qry = 'INSERT INTO tenant(uuid) VALUES(%s)'
    for tenant_uuid in missing_tenants:
        cursor.execute(qry, (tenant_uuid,))


def _get_entities(cursor):
    qry = 'SELECT id, name FROM entity'
    cursor.execute(qry)
    return {row[1]: row[0] for row in cursor.fetchall()}


def _get_existing_tenants(cursor):
    qry = 'SELECT uuid FROM tenant'
    cursor.execute(qry)
    return {row[0] for row in cursor.fetchall()}


def _get_tenants(auth_client):
    return {tenant['name']: tenant['uuid'] for tenant in auth_client.tenants.list()['items']}


def _get_users(cursor):
    qry = 'SELECT uuid, tenant_uuid FROM userfeatures'
    cursor.execute(qry)
    return {row[0]: row[1] for row in cursor.fetchall()}


def _build_entity_tenant_map(auth_client, cursor):
    entity_map = _get_entities(cursor)
    tenant_map = _get_tenants(auth_client)

    entity_tenant_map = {}
    for name, id_ in entity_map.items():
        tenant_uuid = tenant_map.get(name)
        if not tenant_uuid:
            continue
        entity_tenant_map[id_] = tenant_uuid

    return entity_tenant_map


def do_migration(config):
    auth_client = AuthClient(**config['auth'])
    token = auth_client.token.new('xivo_service', expiration=36000)['token']
    auth_client.set_token(token)

    with closing(psycopg2.connect(config['db_uri'])) as conn:
        cursor = conn.cursor()
        entity_tenant_map = _build_entity_tenant_map(auth_client, cursor)
        _create_all_tenants(cursor, entity_tenant_map)
        conn.commit()

        _associate_userfeatures_to_tenants(cursor, entity_tenant_map)
        conn.commit()


def main():
    if os.getenv('XIVO_VERSION_INSTALLED') > '18.04':
        sys.exit(0)

    # Check if the previous migration has been executed since we depend on all tenants
    # existing in wazo-auth
    if not os.path.exists('/var/lib/xivo-upgrade/entity_tenant_migration'):
        print('02_create_tenants_from_entities.py should be executed first')
        sys.exit(1)

    sentinel_file = '/var/lib/xivo-upgrade/entity_tenant_association_migration'
    if os.path.exists(sentinel_file):
        sys.exit(1)

    config = _load_config()
    do_migration(config)

    with open(sentinel_file, 'w'):
        pass


if __name__ == '__main__':
    main()
