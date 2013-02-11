#!/bin/sh

is_executed_file="/var/lib/xivo-upgrade/$(basename $0)"

if [ -f "$is_executed_file" ]; then
    exit
else
    touch "$is_executed_file"
fi

provd_pycli -p '' << EOF
for plugin_name in plugins.installed().keys():
    if plugin_name.startswith('xivo-cisco-spa'):
        devices.using_plugin(plugin_name).reconfigure()

EOF
echo
