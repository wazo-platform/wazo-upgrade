#!/bin/bash
old_fais=" pf-fai pf-fai-dev pf-fai-xivo-1.2-skaro pf-fai-xivo-1.2-skaro-dev"
renamed_packages="pf-xivo-agid"
for package in $renamed_packages; do
    dpkg -l $package | grep -q '^ii'
    if [ $? = 0 ]; then
        apt-get purge $package
    fi
done

$all_packages+=$old_fais
for old_fai in $all_packages; do
    dpkg -l $package | grep -q '^rc'
    if [ $? = 0 ]; then
        dpkg --purge $old_fai
    fi
done


extra="pf-xivo-web-interface"
dpkg -l $extra | grep -q '^rc'
if [ $? = 0 ]; then
    rsync -av /etc/pf-xivo/web-interface /tmp/
    dpkg --purge $extra
    aptitude reinstall pf-xivo-webinterface
    rsync -av /tmp/web-interface/ /etc/pf-xivo/web-interface/
    rm -rf /tmp/web-interface
fi
