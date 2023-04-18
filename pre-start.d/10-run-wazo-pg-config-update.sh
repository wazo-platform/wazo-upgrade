#!/bin/sh
# Copyright 2023 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later
set -e
set -u  # fail if variable is undefined

echo "Updating PostgreSQL config"

/usr/bin/wazo-pg-config-update
