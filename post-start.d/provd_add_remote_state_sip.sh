#!/bin/bash

is_executed_file="/var/lib/xivo-upgrade/$(basename $0)"

if [ -f "$is_executed_file" ]; then
    exit
else
    touch "$is_executed_file"
fi

xivo-provd-cli -p '' >/dev/null << EOF
for device in devices.find():
    if u'remote_state_sip_username' in device:
        continue
    if u'config' not in device:
        continue
    config = configs.get(device[u'config'])
    if not config:
        continue
    sip_lines = config[u'raw_config'].get(u'sip_lines')
    if not sip_lines:
        continue
    sip_line = sip_lines.get(u'1')
    if not sip_line:
        continue
    sip_username = sip_line.get(u'username')
    if not sip_username:
        continue
    device[u'remote_state_sip_username'] = sip_username
    devices.update(device)

EOF
