#!/bin/bash

is_executed_file="/var/lib/xivo-upgrade/$(basename $0)"

if [ -f "$is_executed_file" ]; then
    exit
else
    touch "$is_executed_file"
fi

cron_master="/etc/cron.d/xivo-ha-master"
cron_slave="/etc/cron.d/xivo-ha-slave"

if [ -f "$cron_master" ]; then
    sed -i '/^0/s#$# >/dev/null#' "$cron_master"
fi

if [ -f "$cron_slave" ]; then
    sed -i '/^\*/s#$# >/dev/null#' "$cron_slave"
fi
