#!/usr/bin/env python3
# Copyright 2018 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0+

import logging
import os
import random
import sys
from pwd import getpwnam

from wazo_provd_client import Client

LOCAL_PROVD = "http://localhost:8666/provd"
SCRIPT_NAME = os.path.basename(sys.argv[0])
SCRIPT_EXEC = os.path.join('/', 'var', 'lib', 'xivo-upgrade', SCRIPT_NAME)

logger = logging.getLogger('autoprov_config_migration')
logging.basicConfig(level=logging.INFO)

if os.path.exists(SCRIPT_EXEC):
    logger.debug('Already executed')
    sys.exit(0)

USERNAME_VALUES = '2346789bcdfghjkmnpqrtvwxyzBCDFGHJKLMNPQRTVWXYZ'
USERNAME = 'ap{}'.format(''.join(random.choice(USERNAME_VALUES) for _ in range(8)))
PASSWORD = ''.join(random.choice(USERNAME_VALUES) for _ in range(8))
ASTERISK_AUTOPROV_CONFIG_FILENAME = '/etc/asterisk/pjsip.d/05-autoprov-wizard.conf'
ASTERISK_AUTOPROV_CONFIG_TPL = '''\
[global](+)
default_outbound_endpoint = {username}

[{username}](autoprov-endpoint)
aors = {username}
auth = {username}-auth

[{username}](autoprov-aor)

[{username}-auth]
type = auth
username = {username}
password = {password}
'''

logger.info('generating Asterisk autoprov configuration file')
content = ASTERISK_AUTOPROV_CONFIG_TPL.format(
    username=USERNAME,
    password=PASSWORD,
)

try:
    user = getpwnam('asterisk')
except KeyError:
    logger.warning('failed to find user asterisk')
    logger.warning('failed to create the Asterisk autoprov configuration file')
    sys.exit(1)

try:
    with open(ASTERISK_AUTOPROV_CONFIG_FILENAME, 'w') as fobj:
        fobj.write(content)
    os.chown(ASTERISK_AUTOPROV_CONFIG_FILENAME, user.pw_uid, user.pw_gid)
except IOError as e:
    logger.info('%s', e)
    logger.warning('failed to create the Asterisk autoprov configuration file')

logger.debug("Connecting to provd...")
provd_client = Client('localhost', https=False, prefix='/provd')

to_update = []

logger.debug('Fetching autoprov configuration...')
for config in provd_client.configs.list()['configs']:
    if not config['id'].startswith('autoprov'):
        continue
    to_update.append(config)


logger.info('updating autoprov SIP username: %s configs needs to be updated...', len(to_update))
for config in to_update:
    try:
        config['raw_config']['sip_lines']['1']['username'] = USERNAME
        config['raw_config']['sip_lines']['1']['password'] = PASSWORD
        logger.debug('updating %s', config)
    except KeyError:
        logger.warning('failed to update %s', config)
        continue

    provd_client.configs.update(config['id'], config)

# Create empty file as a flag to avoid running the script again
open(SCRIPT_EXEC, 'w').close()

logger.debug('Done.')
