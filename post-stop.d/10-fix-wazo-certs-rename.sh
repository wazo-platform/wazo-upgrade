#!/bin/bash
# Copyright 2023 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
set -u  # fail if variable is undefined
set -o pipefail  # fail if command before pipe fails

# Remove after Bookworm migration

UPGRADE_SENTINEL=/var/lib/wazo-upgrade/fix-wazo-certs-rename

[ -e "${UPGRADE_SENTINEL}" ] && exit 0

is_package_installed() {
    [ "$(dpkg-query -W -f '${Status}' "$1" 2>/dev/null)" = 'install ok installed' ]
}

if is_package_installed xivo-certs; then
    # Stop nginx to do not trigger reload during upgrade
    # and avoid issue with xivo-certs/wazo-certs renaming
    systemctl stop nginx
    systemctl mask nginx
fi
