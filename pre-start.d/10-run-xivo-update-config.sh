#!/bin/sh
# Copyright 2013-2019 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
set -u  # fail if variable is undefined

echo "Updating Wazo config"

xivo-create-config
xivo-update-config
