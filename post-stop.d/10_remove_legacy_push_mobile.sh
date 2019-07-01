#!/bin/bash
# Copyright 2019 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

sentinel="/var/lib/xivo-upgrade/10_remove_legacy_push_mobile"

[ -e "$sentinel" ] && exit 0

# Remove legacy configuration, everything is preconfigured
# within each services
rm -f /etc/wazo-calld/conf.d/push-mobile.yml \
      /etc/wazo-webhookd/conf.d/mobile.yml \
      /etc/wazo-webhookd/conf.d/51-wazo-push-mobile.yml \
      /etc/wazo-auth/conf.d/mobile.yml

# Remove the obsolete package built by wazo-plugind that will conflict
# the new one
pkg_name="wazo-plugind-wazo-push-mobile-official"
output=$(dpkg-query -W -f '${Status}' "$pkg_name")
if [ "$output" == "install ok installed" ]; then
    apt-get remove -y "$pkg_name"
fi

touch $sentinel
