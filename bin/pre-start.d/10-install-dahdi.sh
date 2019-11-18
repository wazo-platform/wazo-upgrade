#!/bin/sh
# Copyright 2019 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
set -u  # fail if variable is undefined

SENTINEL="/var/lib/wazo-upgrade/install-dahdi"

[ -e "${SENTINEL}" ] && exit 0

if dpkg --compare-versions "${WAZO_VERSION_INSTALLED}" "gt" "19.17"; then
    touch "${SENTINEL}"
    exit 0
fi

echo "Installing Dahdi dependencies"
apt-get install wazo-asterisk-extra-modules

echo "Enabling Dahdi module"
cat<<EOF > /etc/wazo-confgend/conf.d/50_enable_chan_dahdi.yml
enabled_asterisk_modules:
  chan_dahdi.so: true
EOF

touch "${SENTINEL}"
