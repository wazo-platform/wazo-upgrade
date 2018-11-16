#!/usr/bin/env python2
# Copyright 2018 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0+

import logging
import os
import sys

from xivo_provd_client import new_provisioning_client

LOCAL_PROVD = "http://localhost:8666/provd"
SCRIPT_NAME = os.path.basename(sys.argv[0])
SCRIPT_EXEC = os.path.join('/', 'var', 'lib', 'xivo-upgrade', SCRIPT_NAME)
USERNAME = 'anonymous'

logger = logging.getLogger('autoprov_anonymous_migration')
logging.basicConfig(level=logging.INFO)

if os.path.exists(SCRIPT_EXEC):
    logger.debug('Already executed')
    sys.exit(0)

logger.debug("Connecting to provd...")
provd_client = new_provisioning_client(LOCAL_PROVD)
config_manager = provd_client.config_manager()

to_update = []

logger.debug('Fetching autoprov configuration...')
for config in config_manager.find():
    if not config['id'].startswith('autoprov'):
        continue
    to_update.append(config)


logger.info('updating autoprov SIP username: %s configs needs to be updated...', len(to_update))
for config in to_update:
    try:
        config['raw_config']['sip_lines']['1']['username'] = USERNAME
        logger.debug('updating %s', config)
    except KeyError:
        logger.warning('failed to update %s', config)
        continue

    config_manager.update(config)

# Create empty file as a flag to avoid running the script again
open(SCRIPT_EXEC, 'w').close()

logger.debug('Done.')
