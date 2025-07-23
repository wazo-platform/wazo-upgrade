#!/bin/bash
# Copyright 2024 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

# set -e  # logic is based on return code
set -u  # fail if variable is undefined
set -o pipefail  # fail if command before pipe fails

SENTINEL_MIGRATE="/var/lib/wazo-upgrade/migration-provd-db-data"

# wazo-provd-migrate-db return code:
# 0: Everything OK
# 2: Migration already done

if [ -e "${SENTINEL_MIGRATE}" ]; then
    exit
fi

wazo-provd-migrate-db
rc=$?

if [ "$rc" -eq 0 -o "$rc" -eq 2 ]; then
    touch "${SENTINEL_MIGRATE}"
else
    exit $rc
fi
