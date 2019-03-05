#!/usr/bin/env python3
# Copyright 2019 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

import os
import sys

from kombu import (
    Connection,
    Exchange,
    Producer,
)

from xivo.chain_map import ChainMap
from xivo.config_helper import (
    read_config_file_hierarchy,
    parse_config_file,
)
from xivo_auth_client import Client as AuthClient
from xivo_bus import (
    Marshaler,
    Publisher,
)
from xivo_bus.resources.auth.events import TenantCreatedEvent
from xivo_bus.resources.context.event import CreateContextEvent
from xivo_confd_client import Client as ConfdClient

_DEFAULT_CONFIG = {
    'uuid': os.getenv('XIVO_UUID'),
    'config_file': '/etc/wazo-upgrade/config.yml',
    'auth': {
        'key_file': '/var/lib/wazo-auth-keys/wazo-upgrade-key.yml'
    }
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
    publisher = _make_publisher(config)

    tenants = auth_client.tenants.list()['items']
    contexts = confd_client.contexts.list(recurse=True)['items']

    for tenant in tenants:
        _publish_tenant_created_event(publisher, **tenant)

    for context in contexts:
        if context['type'] != 'internal':
            continue
        _publish_context_created_event(publisher, context)


def _publish_context_created_event(publisher, context):
    event = CreateContextEvent(**context)
    publisher.publish(event)


def _publish_tenant_created_event(publisher, uuid, name, **others):
    event = TenantCreatedEvent(uuid, name)
    publisher.publish(event)


def _make_publisher(config):
    bus_url = 'amqp://{username}:{password}@{host}:{port}//'.format(**config['bus'])
    bus_connection = Connection(bus_url)
    bus_exchange = Exchange(config['bus']['exchange_name'], type=config['bus']['exchange_type'])
    bus_producer = Producer(bus_connection, exchange=bus_exchange, auto_declare=True)
    bus_marshaler = Marshaler(config['uuid'])
    return Publisher(bus_producer, bus_marshaler)


def main():
    version_installed = os.getenv('XIVO_VERSION_INSTALLED')
    if version_installed and version_installed > '19.04':
        sys.exit(0)

    sentinel_file = '/var/lib/xivo-upgrade/dird-auto-create-config'
    if os.path.exists(sentinel_file):
        # migration already done
        sys.exit(1)

    _auto_create_config()

    with open(sentinel_file, 'w'):
        pass


if __name__ == '__main__':
    main()
