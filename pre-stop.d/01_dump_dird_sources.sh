#!/bin/sh
# Copyright 2019 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
set -u

OUTPUT_FILE='/var/lib/wazo-upgrade/dird_sources.yml'

if dpkg --compare-versions "${XIVO_VERSION_INSTALLED}" "gt" "19.14"; then
    exit 0
fi

if [ -e "${OUTPUT_FILE}" ]; then
    exit 0
fi

if [ -e "/usr/bin/xivo-confgen" ]; then
    CONFGEN="/usr/bin/xivo-confgen"
else
    CONFGEN="/usr/bin/wazo-confgen"
fi

"${CONFGEN}" dird/sources.yml > "${OUTPUT_FILE}"
echo "dird sources dumped to ${OUTPUT_FILE}"