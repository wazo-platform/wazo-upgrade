#!/usr/bin/env python3
# Copyright 2022 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later
import logging
import os
import re
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
REPO_REGEX = re.compile(r'^(https?)://provd.wazo.community/plugins/1/(testing|stable|archive)/$')
DEFAULT_PLUGIN_CACHE_DIR = '/var/cache/wazo-provd/'
DEFAULT_PLUGIN_DIR = '/var/lib/wazo-provd/plugins/'
SENTINEL_FILE = '/var/lib/wazo-upgrade/replace-provd-py2-plugins'


def _load_key_file(config):
    key_file = parse_config_file(config['auth']['key_file'])
    return {'auth': {'username': key_file['service_id'], 'password': key_file['service_key']}}


def load_config():
    file_config = read_config_file_hierarchy(_DEFAULT_CONFIG)
    key_config = _load_key_file(ChainMap(file_config, _DEFAULT_CONFIG))
    return ChainMap(key_config, file_config, _DEFAULT_CONFIG)


def delete_cached_plugins(cache_dir):
    """Delete plugin cache to ensure provd does not re-use python2 plugins."""
    for plugin in os.listdir(cache_dir):
        file_path = os.path.join(cache_dir, plugin)
        if os.path.isfile(file_path):
            os.remove(file_path)


def wait_until_completed(oip: OperationInProgress, wait=30):
    if oip.state == OIP_SUCCESS:
        return True
    if oip.state == OIP_FAIL or wait <= 0:
        return False
    oip.update()
    wait -= 1
    sleep(1)
    return wait_until_completed(oip, wait)


def update_plugin_repo_url(client: ProvdClient):
    current_url = client.params.get('plugin_server')['value']
    if not current_url:
        return
    match = REPO_REGEX.match(current_url)
    if match:
        proto, variant = match.groups()
        client.params.update('plugin_server', f'{proto}://provd.wazo.community/plugins/2/{variant}/')


def update_plugins(client: ProvdClient, plugin_dir: str):
    # Get all installed plugins that are still installable (i.e. skip old packages that are no longer available)
    installable_plugins = client.plugins.list_installable()['pkgs']
    plugins = [p for p in client.plugins.list_installed()['pkgs'] if p in installable_plugins]

    # Update plugin registry
    if wait_until_completed(client.plugins.update()) is False:
        print('Unable to update repository', file=sys.stderr)
        sys.exit(1)

    # remove old plugins
    for plugin in plugins:
        plugin_name = plugin.replace('xivo-', 'wazo-')
        if wait_until_completed(client.plugins.upgrade(plugin_name)) is False:
            print(f'Failed to install plugin {plugin_name}', file=sys.stderr)
            sys.exit(1)

    # Update devices that were linked to old plugin names
    for device in client.devices.list()['devices']:
        current_plugin = device.get('plugin', None)
        if current_plugin and current_plugin.startswith('xivo-'):
            device['plugin'] = current_plugin.replace('xivo-', 'wazo-')
            client.devices.update(device)


def main():
    if os.path.exists(SENTINEL_FILE):
        sys.exit(0)

    config = load_config()
    provd_config = config['provd']
    auth_client = AuthClient(**config['auth'])
    token_data = auth_client.token.new(expiration=300)
    provd_client = ProvdClient(token=token_data['token'], **provd_config)
    general_config = provd_config.get('general', {})
    plugin_dir = general_config.get('base_storage_dir', DEFAULT_PLUGIN_DIR)
    cache_dir = general_config.get('cache_dir', DEFAULT_PLUGIN_CACHE_DIR)

    delete_cached_plugins(cache_dir)
    update_plugin_repo_url(provd_client)
    update_plugins(provd_client, plugin_dir)

    with open(SENTINEL_FILE, 'w'):
        pass


if __name__ == '__main__':
    main()
