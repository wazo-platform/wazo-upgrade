#!/bin/sh

if [ "$XIVO_VERSION_INSTALLED" \> '15.16' ]; then
    exit 0
fi

curl -s http://localhost/xivo/configuration/json.php/private/provisioning/configregistrar/?act=rebuild_required_config
