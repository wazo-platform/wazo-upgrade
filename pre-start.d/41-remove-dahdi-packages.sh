#!/bin/bash
# Copyright 2021 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
set -u  # fail if variable is undefined
set -o pipefail  # fail if command before pipe fails

SENTINEL="/var/lib/wazo-upgrade/remove-dahdi-packages"
[ -e "${SENTINEL}" ] && exit 0

DAHDI_CONFIG="/etc/asterisk/dahdi-channels.conf"
if [ -e "$DAHDI_CONFIG" ]; then
    touch "${SENTINEL}"
    exit 0
fi

kernel_release=$(ls /lib/modules/ | grep -e "^4.9" -e "^4.19")
for kernel in $kernel_release; do
    apt-get purge -y dahdi-linux-modules-${kernel}
done

touch "${SENTINEL}"
