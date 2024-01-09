#!/bin/bash
# Copyright 2024 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
set -u  # fail if variable is undefined
set -o pipefail  # fail if command before pipe fails

SENTINEL='/var/lib/wazo-upgrade/rename-sync-cron'
CRON_FILENAME='/etc/cron.d/xivo-ha-master'

if [ -e ${SENTINEL} ]; then
    exit 0
fi

if [ -e ${CRON_FILENAME} ]; then
    sed -i 's/xivo-sync/wazo-sync/g' $CRON_FILENAME
fi

touch $SENTINEL
