#!/bin/bash
# Copyright 2024 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
set -u  # fail if variable is undefined
set -o pipefail  # fail if command before pipe fails

SENTINEL_MIGRATE="/var/lib/wazo-upgrade/migration-provd-db-data"
SENTINEL_CLEANUP="/var/lib/wazo-upgrade/migration-provd-db-cleanup"

# wazo-provd-migrate-db return code:
# 0: Everything OK
# 2: Migration already done

if [ ! -e "${SENTINEL_MIGRATE}" ]; then
    shopt -qu -o errexit  # logic is based on return code
    wazo-provd-migrate-db
    rc=$?
    shopt -qs -o errexit

    if [ "$rc" -eq 0 -o "$rc" -eq 2 ]; then
        touch "${SENTINEL_MIGRATE}"
    else
        exit $rc
    fi
fi

if [ ! -e "${SENTINEL_CLEANUP}" ]; then
    # Daily backup should take care of data backup
    rm -f /var/lib/wazo-provd/app.json
    rm -rf /var/lib/wazo-provd/jsondb
    touch "${SENTINEL_CLEANUP}"
fi
