#!/usr/bin/env python

import logging

from xivo_dao.helpers import provd_connector
from xivo_dao.data_handler.line import services as lines
from xivo_dao.data_handler.device import services as devices

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('reset_unassociated_devices_to_autoprov')

logger.info('Fetching wrongly configured devices...')
provd_device_manager = provd_connector.device_manager()

configured_device_ids = {device['id']
                         for device in provd_device_manager.find()
                         if 'config' in device and not device['config'].startswith('autoprov')}
associated_device_ids = {line.device_id for line in lines.find_all()}

wrongly_configured_device_ids = configured_device_ids - associated_device_ids

logger.info('Resetting wrongly configured devices to autoprov...')
for device_id in wrongly_configured_device_ids:
    logger.info('Resetting device {}'.format(device_id))
    try:
        device = devices.get(device_id)
        devices.reset_to_autoprov(device)
    except Exception as e:
        logging.exception(e)

logger.info('Done.')
