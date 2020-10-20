#!/usr/bin/env python3
# Copyright 2020 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

import os
import sys

from wazo_auth_client import Client as AuthClient
from wazo_confd_client import Client as ConfdClient
from xivo.chain_map import ChainMap
from xivo.config_helper import read_config_file_hierarchy, parse_config_file

SENTINEL = '/var/lib/wazo-upgrade/fix-endpoint_sip_template-order'
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


def order_templates(expected, configured):
    next_index = 0
    for i, uuid in enumerate(configured):
        if uuid not in expected:
            # Not maintained by Wazo, leave it alone
            continue

        if uuid == expected[next_index]:
            # Its in the good position, leave it alone
            next_index += 1
            continue

        # Swap position
        try:
            current_position = configured.index(expected[next_index])
            configured[i], configured[current_position] = configured[current_position], configured[i]
        except ValueError:
            # This template is not configured for this endpoint (WebRTC on trunks for example)
            pass
        finally:
            next_index += 1

    return configured


def main():
    if os.path.exists(SENTINEL):
        sys.exit(0)

    config = load_config()
    auth_client = AuthClient(**config['auth'])
    token_data = auth_client.token.new(expiration=900)

    confd_client = ConfdClient(**config['confd'])
    confd_client.set_token(token_data['token'])

    tenant_configs = confd_client.tenants.list(recurse=True)

    tenant_templates = {}

    for config in tenant_configs['items']:
        if not config['sip_templates_generated']:
            continue

        tenant_templates[config['uuid']] = [
            # Global is always first
            config['global_sip_template_uuid'],

            # Line templates
            config['webrtc_sip_template_uuid'],
            config['webrtc_video_sip_template_uuid'],

            # Trunk templates
            config['registration_trunk_sip_template_uuid'],
        ]

    for tenant_uuid, templates in tenant_templates.items():
        endpoints = confd_client.endpoints_sip.list(tenant_uuid=tenant_uuid)
        for endpoint in endpoints['items']:
            selected_templates = [template['uuid'] for template in endpoint['templates']]

            # We need at least 2 templates to have an ordering problem
            if len(set(selected_templates).intersection(set(templates))) < 2:
                continue

            endpoint['templates'] = [{'uuid': uuid} for uuid in order_templates(templates, selected_templates)]
            confd_client.endpoints_sip.update(endpoint)

    with open(SENTINEL, 'w') as f:
        f.write('')

if __name__ == '__main__':
    main()
