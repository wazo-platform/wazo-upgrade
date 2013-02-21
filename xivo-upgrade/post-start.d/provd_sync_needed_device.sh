#!/bin/bash
is_executed_file="/var/lib/xivo-upgrade/$(basename $0)"

if [ ! -f "$is_executed_file" ]; then
    curl -s http://localhost/xivo/configuration/json.php/private/provisioning/configregistrar/?act=sync_bsfilter_devices
    touch "$is_executed_file"
fi 