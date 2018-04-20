#!/usr/bin/env python3
# Copyright 2018 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0+

import psycopg2
import os
import sys

from contextlib import closing
from xivo.chain_map import ChainMap
from xivo.config_helper import read_config_file_hierarchy

_DEFAULT_CONFIG = {
    'config_file': '/etc/wazo-upgrade/config.yml',
}


def _load_config():
    file_config = read_config_file_hierarchy(_DEFAULT_CONFIG)
    return ChainMap(file_config, _DEFAULT_CONFIG)


def _associate_userfeatures_to_tenants(cursor, entity_tenant_map):
    qry = 'UPDATE userfeatures SET tenant_uuid=%s WHERE entityid=%s'
    for entityid, tenant_uuid in entity_tenant_map.items():
        cursor.execute(qry, (tenant_uuid, entityid))


def _get_entities(cursor):
    qry = 'SELECT id, tenant_uuid FROM entity'
    cursor.execute(qry)
    return {entity_id: tenant_uuid for (entity_id, tenant_uuid) in cursor.fetchall()}


def do_migration(config):
    with closing(psycopg2.connect(config['db_uri'])) as conn:
        cursor = conn.cursor()
        entity_tenant_map = _get_entities(cursor)
        _associate_userfeatures_to_tenants(cursor, entity_tenant_map)
        conn.commit()


def main():
    if os.getenv('XIVO_VERSION_INSTALLED') > '18.04':
        sys.exit(0)

    # Check if the previous migration has been executed since we depend on all tenants
    # existing in wazo-auth
    if not os.path.exists('/var/lib/xivo-upgrade/entity_tenant_migration'):
        print('21_create_tenants_from_entities.py should be executed first')
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
