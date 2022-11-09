#!/usr/bin/env python3
# Copyright 2022 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later
import logging
import os
import sys
from time import sleep

from wazo_auth_client import Client as AuthClient
from wazo_provd_client import Client as ProvdClient
from provd.operation import OIP_WAITING, OIP_PROGRESS, OIP_SUCCESS, OIP_FAIL, OperationInProgress
from xivo.chain_map import ChainMap
from xivo.config_helper import read_config_file_hierarchy, parse_config_file


logger = logging.getLogger('replace_py2_provd_plugins')
logging.basicConfig(level=logging.INFO)

_DEFAULT_CONFIG = {
    'config_file': '/etc/wazo-upgrade/config.yml',
    'auth': {
        'key_file': '/var/lib/wazo-auth-keys/wazo-upgrade-key.yml'
    }
}
PLUGIN_CACHE_DIR = '/var/cache/wazo-provd/'
SENTINEL_FILE = '/var/lib/wazo-upgrade/replace-provd-py2-plugins'


def _load_key_file(config):
    key_file = parse_config_file(config['auth']['key_file'])
    return {'auth': {'username': key_file['service_id'], 'password': key_file['service_key']}}


def load_config():
    file_config = read_config_file_hierarchy(_DEFAULT_CONFIG)
    key_config = _load_key_file(ChainMap(file_config, _DEFAULT_CONFIG))
    return ChainMap(key_config, file_config, _DEFAULT_CONFIG)


def delete_cached_plugins():
    """Delete plugin cache to ensure provd does not re-use python2 plugins."""
    for plugin in os.listdir(PLUGIN_CACHE_DIR):
        file_path = os.path.join(PLUGIN_CACHE_DIR, plugin)
        if os.path.isfile(file_path):
            os.remove(file_path)


def wait_until_completed(oip: OperationInProgress, wait=5):
    if oip.state == OIP_SUCCESS:
        return True
    if oip.state == OIP_FAIL or wait <= 0:
        return False
    oip.update()
    wait -= 1
    sleep(.5)
    return wait_until_completed(oip, wait)


def update_plugin_repo_url(client: ProvdClient):
    current_url = client.params.get('plugin_server')['value']
    if current_url and current_url.startswith('http://provd.wazo.community/plugins/1/'):
        new_url = current_url.replace(
            'http://provd.wazo.community/plugins/1/',
            'http://provd.wazo.community/plugins/2/',
        )
        client.params.update('plugin_server', new_url)


def remove_and_reinstall_plugins(client: ProvdClient):
    installed_plugins = list(client.plugins.list()['plugins'])

    # remove old plugins
    for plugin in installed_plugins:
        client.plugins.uninstall(plugin)

    # Update plugin registry
    wait_until_completed(client.plugins.update())

    # Rename old xivo plugins with the wazo named ones and use a set to avoid duplicates since some were combined
    plugins_to_install = {p.replace('xivo-', 'wazo-') for p in installed_plugins}

    for plugin in plugins_to_install:
        client.plugins.install(plugin)


def main():
    if os.path.exists(SENTINEL_FILE):
        sys.exit(0)

    config = load_config()
    provd_config = config['provd']
    auth_client = AuthClient(**config['auth'])
    token_data = auth_client.token.new(expiration=300)
    provd_client = ProvdClient(token=token_data['token'], **provd_config)

    delete_cached_plugins()
    update_plugin_repo_url(provd_client)
    remove_and_reinstall_plugins(provd_client)

    with open(SENTINEL_FILE, 'w'):
        pass


if __name__ == '__main__':
    main()
