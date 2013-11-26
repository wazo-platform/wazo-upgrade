#!/bin/bash

if [ -f /etc/pf-xivo/ha.conf -a -n "$UPGRADING_POSTGRESQL" ]; then
    echo "Updating configuration for HA..."
    curl -X POST -H "Content-Type: application/json" -d @/etc/pf-xivo/ha.conf http://localhost:8668/update_ha_config &>>/dev/null
    xivo-service restart all
fi
