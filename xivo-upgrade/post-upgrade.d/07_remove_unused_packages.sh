#!/bin/bash
old_fais="pf-fai pf-fai-dev pf-fai-xivo-1.2-skaro pf-fai-xivo-1.2-skaro-dev"
renamed_packages="pf-xivo-agid"
for package in $renamed_packages; do
    dpkg -l $package | grep -q '^ii'
    if [ $? = 0 ]; then
        apt-get purge $package > /dev/null
    fi
done

all_packages+="$renamed_packages $old_fais"
for old_fai in $all_packages; do
    dpkg -l $old_fai | grep -q '^rc'
    if [ $? = 0 ]; then
        dpkg --purge $old_fai > /dev/null
    fi
done

extra="pf-xivo-web-interface-config"
dpkg -l $extra | grep -q '^rc'
if [ $? = 0 ]; then
    rsync -av /etc/pf-xivo/web-interface /tmp/ > /dev/null
    dpkg --purge $extra > /dev/null
    rsync -av /tmp/web-interface/ /etc/pf-xivo/web-interface/ > /dev/null
    rm -rf /tmp/web-interface > /dev/null
    apt-get install --reinstall pf-xivo-web-interface > /dev/null
fi
