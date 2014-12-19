#!/bin/sh

is_executed_file="/var/lib/xivo-upgrade/$(basename $0)"

if [ -f "$is_executed_file" ]; then
    exit
else
    touch "$is_executed_file"
fi

curl -s http://localhost/xivo/configuration/json.php/private/provisioning/configregistrar/?act=rebuild_required_config
