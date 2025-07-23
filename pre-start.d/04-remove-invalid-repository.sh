#!/bin/sh
# Copyright 2025 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later
#
set -e
set -u  # fail if variable is undefined

SENTINEL="/var/lib/wazo-upgrade/remove-bullseye-backports"

[ -e "${SENTINEL}" ] && exit 0

sed -i "/bullseye-backports/d" /etc/apt/sources.list

touch "${SENTINEL}"
