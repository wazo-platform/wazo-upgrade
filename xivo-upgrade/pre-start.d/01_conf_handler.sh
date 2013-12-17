#!/bin/bash

xivo_ini_path="/etc/xivo/web-interface/xivo.ini"
ipbx_config_file="/etc/xivo/web-interface/ipbx.ini"
WEBI_CONFIG="/etc/xivo/web-interface"

for file in xivo ipbx cti; do
    ini_file="${WEBI_CONFIG}/${file}.ini"
    if [ -f ${ini_file}.xivo-upgrade-old ]; then
        mv ${ini_file}.xivo-upgrade-old ${ini_file}
    fi
done

if [ -f "$xivo_ini_path" ]; then
    sed -i -e 's/^language = fr/language = en/' -e 's/^territory = FR/territory = US/' "$xivo_ini_path"
fi

if [ -f $ipbx_config_file ]; then
    sed -i 's#/var/backups/xivo#/var/backups/xivo#' $ipbx_config_file
fi
