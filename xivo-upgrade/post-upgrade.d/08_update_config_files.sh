#!/bin/bash

ipbx_config_file="/etc/pf-xivo/web-interface/ipbx.ini"

if [ -f $ipbx_config_file ]; then
    sed -i 's#/var/backups/pf-xivo#/var/backups/xivo#' $ipbx_config_file
fi

