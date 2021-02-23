#!/bin/bash
# Copyright 2021 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

# set -e  # logic based on error return code
set -u  # fail if variable is undefined
set -o pipefail  # fail if command before pipe fails

SENTINEL_INDEX="/var/lib/wazo-upgrade/migration-call-log-index"
SENTINEL_TABLES="/var/lib/wazo-upgrade/migration-call-log-tables"

# wazo-call-logd-migration-db return code:
# 0: Everything OK
# 2: Migration already done
# 3: Too much entries to process

if [ ! -e "${SENTINEL_INDEX}" ]; then
    wazo-call-logd-migrate-db -i
    rc=$?

    if [ "$rc" -eq 0 ]; then
        touch "${SENTINEL_INDEX}"
    elif [ "$rc" -eq 2 ]; then
        touch "${SENTINEL_INDEX}"
        touch "${SENTINEL_TABLES}"
    else
        exit $rc
    fi
fi

if [ ! -e "${SENTINEL_TABLES}" ]; then
    wazo-call-logd-migrate-db -m 10000000
    rc=$?

    if [ "$rc" -eq 0 -o "$rc" -eq 2 ]; then
        touch "${SENTINEL_TABLES}"
    elif [ "$rc" -eq 3 ]; then
        echo "ERROR: You need to run 'wazo-call-logd-migrate-db' manually to complete migration"
    else
        exit $rc
    fi
fi
