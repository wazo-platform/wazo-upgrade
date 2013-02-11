#!/bin/sh

version=$(cat /usr/share/pf-xivo/XIVO-VERSION)
xivo_ini_path='/etc/pf-xivo/web-interface/xivo.ini'
ipbx_config_file="/etc/pf-xivo/web-interface/ipbx.ini"

if [ -f "$xivo_ini_path" ]; then
    sed -i -e 's/^language = fr/language = en/' -e 's/^territory = FR/territory = US/' "$xivo_ini_path"
fi

if [ -f $ipbx_config_file ]; then
    sed -i 's#/var/backups/pf-xivo#/var/backups/xivo#' $ipbx_config_file
fi
