#!/usr/bin/env python3
# Copyright 2019 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

import argparse
import os
import sys
import requests

from xivo.chain_map import ChainMap
from xivo.config_helper import (
    read_config_file_hierarchy,
    parse_config_file,
)
from xivo_auth_client import Client as AuthClient
from xivo_confd_client import Client as ConfdClient

_DEFAULT_CONFIG = {
    'uuid': os.getenv('XIVO_UUID'),
    'config_file': '/etc/wazo-upgrade/config.yml',
    'auth': {
        'key_file': '/var/lib/wazo-auth-keys/wazo-upgrade-key.yml'
    }
}

CONFERENCE_SOURCE_BODY = {
    'auth': {
        'host': 'localhost',
        'port': 9497,
        'verify_certificate': '/usr/share/xivo-certs/server.crt',
        'key_file': '/var/lib/wazo-auth-keys/wazo-dird-wazo-backend-key.yml',
        'version': '0.1',
    },
    'confd': {
        'host': 'localhost',
        'port': 9486,
        'https': True,
        'verify_certificate': '/usr/share/xivo-certs/server.crt',
        'version': '1.1',
    },
    'format_columns': {
        'phone': '{exten}',
        'name': '{firstname} {lastname}',
    },
    'searched_columns': ['firstname', 'lastname', 'exten'],
    'first_matched_columns': [],
}


def _load_config():
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


def _auto_create_config():
    config = _load_config()
    auth_client = AuthClient(**config['auth'])
    token = auth_client.token.new('wazo_user', expiration=36000)['token']
    auth_client.set_token(token)
    confd_client = ConfdClient(token=token, **config['confd'])

    tenants = auth_client.tenants.list()['items']

    base_url = 'https://{host}:{port}/{version}'.format(
        **config['dird']
    )
    profiles_url = '{}/profiles'.format(base_url)
    conference_url = '{}/backends/conference/sources'.format(base_url)
    headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Auth-Token': token,
    }
    for tenant in tenants:
        name = tenant['name']
        if name == 'master':
            continue

        headers['Wazo-Tenant'] = tenant['uuid']

        conference_body = dict(name='auto_conference_{}'.format(name), **CONFERENCE_SOURCE_BODY)
        conference = requests.post(
            conference_url,
            headers=headers,
            json=conference_body,
            verify=config['dird']['verify_certificate'],
        ).json()

        response = requests.get(
            profiles_url,
            headers={
                'Accept': 'application/json',
                'X-Auth-Token': token,
                'Wazo-Tenant': tenant['uuid'],
            },
            verify=config['dird']['verify_certificate'],
        ).json()

        for profile in response['items']:
            profile['services']['lookup']['sources'].append(conference)
            profile['services']['favorites']['sources'].append(conference)
            requests.put(
                '{}/{}'.format(profiles_url, profile['uuid']),
                json=profile,
                headers=headers,
                verify=config['dird']['verify_certificate'],
            )


def main():
    args = parse_args()
    if not args.force:
        version_installed = os.getenv('XIVO_VERSION_INSTALLED')
        if version_installed >= '19.07':
            sys.exit(0)

    sentinel_file = '/var/lib/xivo-upgrade/dird-auto-create-config-v2.x2'
    if os.path.exists(sentinel_file):
        # migration already done
        sys.exit(1)

    _auto_create_config()

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
