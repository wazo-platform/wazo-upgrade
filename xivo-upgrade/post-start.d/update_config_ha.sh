#!/bin/bash

if [ -f /etc/pf-xivo/ha.conf ]; then
    echo "Updating configuration for HA..."
    curl -X POST -H "Content-Type: application/json" -d @/etc/pf-xivo/ha.conf http://localhost:8668/update_ha_config &>>/dev/null
fi
