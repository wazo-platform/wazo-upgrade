#!/bin/bash

webi_config_path='/etc/xivo/web-interface'

if [ $XIVO_VERSION_INSTALLED \< '13.04' ]; then
    for file in xivo ipbx cti; do
        mv ${webi_config_path}/${file}.ini ${webi_config_path}/${file}.ini.xivo-upgrade-old
    done
fi