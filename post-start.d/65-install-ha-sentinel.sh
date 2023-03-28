#!/bin/bash
# Copyright 2023 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
set -u
set -o pipefail

HA_CONF=/etc/xivo/ha.conf
UPGRADE_SENTINEL=/var/lib/wazo-upgrade/install-ha-sentinel
if [ -f "$UPGRADE_SENTINEL" ]; then
    exit 0
elif [ -f "$HA_CONF" ]; then
    node_type=$(jq -r '.node_type' $HA_CONF)
    if [ "$node_type" = "slave" ]; then
        rm -f /var/lib/wazo/is-primary
        touch /var/lib/wazo/is-secondary
    elif [ "$node_type" = "master" ]; then
        rm -f /var/lib/wazo/is-secondary
        touch /var/lib/wazo/is-primary
    fi
fi
touch "$UPGRADE_SENTINEL"

