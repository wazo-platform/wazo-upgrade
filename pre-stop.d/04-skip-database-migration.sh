#!/bin/bash
# Copyright 2019 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

if [ -n $XIVO_VERSION_INSTALLED ] && [ $XIVO_VERSION_INSTALLED \< '18.04' ]
then
    echo "xivo-manage-db xivo-manage-db/db-skip boolean true" | debconf-set-selections
fi
