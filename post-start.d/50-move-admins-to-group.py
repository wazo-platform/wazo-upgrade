#!/usr/bin/env python3
# Copyright 2022 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

import os
import sys

from wazo_auth_client import Client as AuthClient
from xivo.chain_map import ChainMap
from xivo.config_helper import read_config_file_hierarchy, parse_config_file

ADMIN_GROUP_SLUG = 'wazo_default_admin_group'
ADMIN_POLICY_SLUG = 'wazo_default_admin_policy'
SENTINEL = '/var/lib/wazo-upgrade/move-admins-to-group'
_DEFAULT_CONFIG = {
    'config_file': '/etc/wazo-upgrade/config.yml',
    'auth': {
        'key_file': '/var/lib/wazo-auth-keys/wazo-upgrade-key.yml'
    }
}


def load_config():
    file_config = read_config_file_hierarchy(_DEFAULT_CONFIG)
    key_config = _load_key_file(ChainMap(file_config, _DEFAULT_CONFIG))
    return ChainMap(key_config, file_config, _DEFAULT_CONFIG)


def _load_key_file(config):
    key_file = parse_config_file(config['auth']['key_file'])
    return {
        'auth': {
            'username': key_file['service_id'],
            'password': key_file['service_key'],
        },
    }


class AdminGroupNotFound(Exception):
    def __init__(self, group_name, tenant_uuid):
        super().__init__(f'{group_name}: no such group in tenant {tenant_uuid}')


def list_admin_users(auth_client):
    return auth_client.users.list(recurse=True, policy_slug=ADMIN_POLICY_SLUG)['items']


def get_admin_policy_uuid(auth_client):
    policy = auth_client.policies.get(ADMIN_POLICY_SLUG)
    return policy['uuid']


def move_admin_to_group(auth_client, admin, policy_uuid):
    tenant_uuid = admin['tenant_uuid']
    groups = auth_client.groups.list(slug=ADMIN_GROUP_SLUG, tenant_uuid=tenant_uuid)['items']
    try:
        group = groups[0]
    except IndexError:
        raise AdminGroupNotFound(ADMIN_GROUP_SLUG, tenant_uuid)

    auth_client.groups.add_user(group['uuid'], admin['uuid'])
    auth_client.users.remove_policy(admin['uuid'], policy_uuid)


def main():
    if os.path.exists(SENTINEL):
        sys.exit(0)

    config = load_config()
    auth_client = AuthClient(**config['auth'])
    token_data = auth_client.token.new(expiration=900)
    auth_client.set_token(token_data['token'])

    admin_policy_uuid = get_admin_policy_uuid(auth_client)

    admins = list_admin_users(auth_client)
    for admin in admins:
        move_admin_to_group(auth_client, admin, admin_policy_uuid)

    with open(SENTINEL, 'w') as f:
        f.write('')


if __name__ == '__main__':
    main()
