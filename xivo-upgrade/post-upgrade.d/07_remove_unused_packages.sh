#!/bin/bash
old_fais="pf-fai pf-fai-dev pf-fai-xivo-1.2-skaro pf-fai-xivo-1.2-skaro-dev"
renamed_packages="pf-xivo-agid pf-xivo-base-config pf-xivo-fetchfw pf-xivo-web-interface-config"
postrm_webi_config="/var/lib/dpkg/info/pf-xivo-web-interface-config.postrm"

echo "cleanup outdated config files"
if [ -f $postrm_webi_config ]; then
    rm $postrm_webi_config > /dev/null
fi

# cleanup pf-xivo-base-config.postrm file to allow package purge
base_config_postrm="/var/lib/dpkg/info/pf-xivo-base-config.postrm"
xivo_config_postrm="/var/lib/dpkg/info/xivo-config.postrm"
if [ -f $base_config_postrm ]; then
    cp $xivo_config_postrm $base_config_postrm
    sed -i 's/xivo-config/pf-xivo-base-config/' $base_config_postrm
fi

for package in $renamed_packages; do
    dpkg -l $package 2> /dev/null | grep -q '^ii'
    if [ $? = 0 ]; then
        apt-get purge $package > /dev/null
    fi
done

all_packages+="$renamed_packages $old_fais"
for old_fai in $all_packages; do
    dpkg -l $old_fai 2> /dev/null | grep -q '^rc'
    if [ $? = 0 ]; then
        dpkg --purge $old_fai > /dev/null
    fi
done
