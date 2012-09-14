#!/bin/bash
old_fai=" pf-fai pf-fai-dev pf-fai-xivo-1.2-skaro pf-fai-xivo-1.2-skaro-dev"
renamed_packages="pf-xivo-agid"
for package in $renamed_packages; do
    dpkg -l $package | grep -q '^ii'
    if [ $? = 0 ]; then
        apt-get purge $package
    fi
done
dpkg --purge $old_fai
