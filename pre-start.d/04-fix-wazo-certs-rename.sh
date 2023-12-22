#!/bin/bash
# Copyright 2023 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
set -u  # fail if variable is undefined
set -o pipefail  # fail if command before pipe fails

# Remove after Bookworm migration

UPGRADE_SENTINEL=/var/lib/wazo-upgrade/fix-wazo-certs-rename

[ -e "${UPGRADE_SENTINEL}" ] && exit 0

# see ../post-stop.d/10-fix-wazo-certs-rename.sh
systemctl unmask nginx
systemctl restart nginx

touch "$UPGRADE_SENTINEL"
