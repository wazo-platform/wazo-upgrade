#!/bin/bash

if [ -f /etc/xivo/ha.conf -a -n "$UPGRADING_POSTGRESQL" ]; then
    echo "Updating configuration for HA..."
    curl -X POST -H "Content-Type: application/json" -d @/etc/xivo/ha.conf http://localhost:8668/update_ha_config &>>/dev/null
    wazo-service restart all
fi
