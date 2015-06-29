#!/bin/bash

if [ "$XIVO_VERSION_INSTALLED" \> '15.12' ]; then
    exit 0
fi

cron_master='/etc/cron.d/xivo-ha-master'

if [ -f "$cron_master" ] && ! grep -q xivo-sync "$cron_master"; then
    sed -i '$a\0 * * * * root /usr/bin/xivo-sync >/dev/null' "$cron_master"
fi
