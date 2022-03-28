#!/usr/bin/env python3
# Copyright 2022 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

import requests
import os
import sys
import logging

from urllib3.exceptions import InsecureRequestWarning

from wazo_auth_client import Client as AuthClient
from wazo_amid_client import Client as AmidClient

from xivo.chain_map import ChainMap
from xivo.config_helper import read_config_file_hierarchy, parse_config_file


_DEFAULT_CONFIG = {
    'config_file': '/etc/wazo-upgrade/config.yml',
    'auth': {
        'key_file': '/var/lib/wazo-auth-keys/wazo-upgrade-key.yml'
    }
}
logger = logging.getLogger('upgrade_official_plugins')
logging.basicConfig(level=logging.INFO)

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


def list_users_with_mobile_refresh_tokens(auth_client):
    response = auth_client.refresh_tokens.list(recurse=True)
    user_uuids = set()
    for token in response['items']:
        if not token['mobile']:
            continue
        user_uuids.add(token['user_uuid'])
    return list(user_uuids)


def update_hint(amid_client, user_uuid):
    hint = f'Custom:{user_uuid}-mobile'
    logger.debug('updating %s', hint)
    amid_client.action(
        'Setvar',
        {
            'Variable': f'DEVICE_STATE({hint})',
            'Value': 'NOT_INUSE',
        },
    )


def update_hints(amid_client, user_uuids):
    for user_uuid in user_uuids:
        update_hint(amid_client, user_uuid)


def main():
    sentinel_file = '/var/lib/wazo-upgrade/set-mobile-hints'
    if os.path.exists(sentinel_file):
        sys.exit(1)

    config = _load_config()
    auth_client = AuthClient(**config['auth'])
    amid_client = AmidClient(**config['amid'])
    token = auth_client.token.new('wazo_user', expiration=5*60)
    auth_client.set_token(token['token'])
    amid_client.set_token(token['token'])

    mobile_users = list_users_with_mobile_refresh_tokens(auth_client)
    update_hints(amid_client, mobile_users)

    with open(sentinel_file, 'w'):
        pass


if __name__ == '__main__':
    main()
