#!/bin/bash
# Copyright 2025 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
set -u  # fail if variable is undefined
set -o pipefail  # fail if command before pipe fails

SENTINEL="/var/lib/wazo-upgrade/dird-user-sync-tenant"
if [[ -f $SENTINEL ]]; then
    exit
fi
TOKEN=$(wazo-auth-cli token create)
wazo-confd-cli --token $TOKEN user list -c uuid -c tenant_uuid -c country --recurse -fjson --noindent | wazo-dird-user-sync
touch $SENTINEL
