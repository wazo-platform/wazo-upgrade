#!/bin/bash
version=$(cat /usr/share/pf-xivo/XIVO-VERSION)
is_executed_file="/var/lib/xivo-upgrade/$(basename $0)"

if [ -f "$is_executed_file" ]; then
    exit
else
    touch "$is_executed_file"
fi

curl -s http://localhost/xivo/configuration/json.php/private/provisioning/configregistrar/?act=sync_bsfilter_devices
