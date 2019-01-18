#!/usr/bin/env python3
# Copyright 2017-2018 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

import logging
import urllib3

from wazo_plugind_client import Client as PlugindClient
from xivo.chain_map import ChainMap
from xivo.config_helper import read_config_file_hierarchy, parse_config_file
from xivo_auth_client import Client as AuthClient

logger = logging.getLogger('upgrade_official_plugins')
logging.basicConfig(level=logging.INFO)
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

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
    return {'auth': {'username': key_file['service_id'],
                     'password': key_file['service_key']}}


def main():
    config = load_config()
    auth_client = AuthClient(**config['auth'])
    token_data = auth_client.token.new(expiration=300)

    plugind_client = PlugindClient(**config['plugind'])
    plugind_client.set_token(token_data['token'])

    plugin_list = plugind_client.market.list(namespace='official', installed=True)
    for plugin in plugin_list['items']:
        for version in plugin['versions']:
            if version['upgradable'] is True:
                logger.info('Upgrading plugin %s ...', plugin['name'])
                plugind_client.plugins.install(method='market',
                                               options={'namespace': 'official',
                                                        'name': plugin['name'],
                                                        'version': version['version']})
                break


if __name__ == '__main__':
    main()
