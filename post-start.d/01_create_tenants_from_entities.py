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


def _entity_to_tenant(row):
    name, number, line_1, line_2, city, state, zip_code, country = row

    body = {'name': name}
    if number:
        body['number'] = number

    address = {}
    if line_1:
        address['line_1'] = line_1
    if line_2:
        address['line_2'] = line_2
    if city:
        address['city'] = city
    if state:
        address['state'] = state
    if country:
        address['country'] = country

    if address:
        body['address'] = address

    return body


def _get_entities(cursor):
    qry = 'SELECT name, phonenumber, address1, address2, city, state, zipcode, country from entity'
    cursor.execute(qry)
    return [_entity_to_tenant(row) for row in cursor.fetchall()]


def _get_existing_tenant_names(auth_client):
    return {tenant['name'] for tenant in auth_client.tenants.list()['items']}


def do_migration(config):
    with closing(psycopg2.connect(config['db_uri'])) as conn:
        entities = _get_entities(conn.cursor())

    auth_client = AuthClient(**config['auth'])
    token = auth_client.token.new('xivo_service', expiration=36000)['token']
    auth_client.set_token(token)

    existing_tenant_names = _get_existing_tenant_names(auth_client)

    for tenant in entities:
        if tenant['name'] in existing_tenant_names:
            continue
        auth_client.tenants.new(**tenant)


def main():
    if os.getenv('XIVO_VERSION_INSTALLED') > '18.04':
        sys.exit(0)

    sentinel_file = '/var/lib/xivo-upgrade/entity_tenant_migration'
    if os.path.exists(sentinel_file):
        sys.exit(1)

    config = _load_config()
    do_migration(config)

    with open(sentinel_file, 'w'):
        pass


if __name__ == '__main__':
    main()
