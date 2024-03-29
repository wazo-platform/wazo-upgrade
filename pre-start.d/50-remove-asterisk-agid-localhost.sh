#!/bin/bash
# Copyright 2024 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

SENTINEL="/var/lib/wazo-upgrade/remove-asterisk-agid-localhost"

[ -e "${SENTINEL}" ] && exit 0

# If the config file was customized, skip the upgrade script next time
# The sha256sum comes from the file generated by the Ansible installer until Wazo 24.02
# File content:
# [globals](+)
# XIVO_AGID_IP = localhost
if [ "$(sha256sum /etc/asterisk/extensions.d/engine-api.conf | awk '{print $1}')" = \
        "b119bc7d71316f10b72fcfb966d4520dc4636c1d789e9474033c07e49c546169" ] ; then
    rm -f /etc/asterisk/extensions.d/engine-api.conf
    asterisk -rx 'dialplan reload'
fi

touch "${SENTINEL}"
