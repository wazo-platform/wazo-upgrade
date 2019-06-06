#!/usr/bin/env python
# Copyright 2018-2019 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

import logging
import requests

from wazo_auth_client import Client as AuthClient
from wazo_confd_client import Client as ConfdClient
from wazo_provd_client import Client as ProvdClient
from xivo.chain_map import ChainMap
from xivo.config_helper import read_config_file_hierarchy, parse_config_file

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


config = load_config()
auth_client = AuthClient(**config['auth'])
token_data = auth_client.token.new(expiration=300)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('reset_unassociated_devices_to_autoprov')

logger.debug('Fetching wrongly configured devices...')

confd_client = ConfdClient(token=token_data['token'], **config['confd'])
provd_client = ProvdClient(token=token_data['token'], **config['provd'])

session = requests.Session()
session.headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'X-Auth-Token': token_data['token'],
}

devices = provd_client.devices.list()['devices']

lines = confd_client.lines.list(recurse=True)['items']

configured_device_ids = {device['id']
                         for device in devices
                         if 'config' in device and not device['config'].startswith('autoprov')}

associated_device_ids = {line['device_id'] for line in lines}

wrongly_configured_device_ids = configured_device_ids - associated_device_ids

logger.debug('Resetting wrongly configured devices to autoprov...')

for device_id in wrongly_configured_device_ids:
    logger.info('Resetting device {}'.format(device_id))
    try:
        confd_client.devices.autoprov(device_id)
    except requests.HTTPError as e:
        logger.error(e)

    confd_client.devices.synchronize(device_id)

logger.debug('Done.')
