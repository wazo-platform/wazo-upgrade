#!/bin/bash

if [ "$XIVO_VERSION_INSTALLED" \> '15.19' ]; then
    exit 0
fi

is_executed_file="/var/lib/xivo-upgrade/$(basename $0)"

if [ -f "$is_executed_file" ]; then
    exit
else
    touch "$is_executed_file"
fi

su - -c "psql -c 'update linefeatures set num = 1 where num = 0;' asterisk > /dev/null" postgres
curl -s http://localhost/xivo/configuration/json.php/private/provisioning/configregistrar/?act=rebuild_required_config
