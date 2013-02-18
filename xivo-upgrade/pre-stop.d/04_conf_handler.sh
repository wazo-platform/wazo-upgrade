#!/bin/sh

version=$(cat /usr/share/pf-xivo/XIVO-VERSION)
webi_config_path='/etc/pf-xivo/web-interface'

if [ $version \< '13.04' ]; then
    for file in xivo ipbx cti; do
        mv ${webi_config_path}/${file}.ini ${webi_config_path}/${file}.ini.xivo-upgrade-old
    done
fi