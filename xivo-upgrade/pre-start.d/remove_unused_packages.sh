#!/bin/bash
renamed_packages="pf-xivo-agid
				pf-xivo-base-config
				pf-xivo-fetchfw
				pf-xivo-provd
				pf-xivo-dxtora
				pf-xivo-dhcpd-update
				pf-xivo-monitoring
				pf-xivo-web-interface
				pf-xivo-web-interface-config
				pf-xivo-sysconfd"

echo "cleanup outdated config files"

# cleanup pf-xivo-base-config.postrm file to allow package purge
base_config_postrm="/var/lib/dpkg/info/pf-xivo-base-config.postrm"
xivo_config_postrm="/var/lib/dpkg/info/xivo-config.postrm"
if [ -f $base_config_postrm ]; then
    cp $xivo_config_postrm $base_config_postrm
    sed -i 's/xivo-config/pf-xivo-base-config/' $base_config_postrm
fi

# cleanup pf-xivo-sysconfd backup directory
old_sysconfd_directory="/var/backups/pf-xivo-sysconfd"
new_sysconfd_directory="/var/backups/xivo-sysconfd"
if [ -d $old_sysconfd_directory ]; then
    rsync -av $old_sysconfd_directory/ $new_sysconfd_directory/ > /dev/null
    rm -rf $old_sysconfd_directory/*
fi

# sync old pf-xivo-provd data
old_provd_directory="/var/lib/pf-xivo-provd"
if [ -d $old_provd_directory ]; then
    rsync -av $old_provd_directory/ /var/lib/xivo-provd/ > /dev/null
    rm -rf $old_provd_directory
fi

# remove old postgresql-common and postgresql-client-common
pg_common_version=$(LANG=C apt-cache policy postgresql-common | grep Installed | awk '{print $2}')
if [ "$pg_common_version" = "140+0.xivo-backport-2" ]; then
    apt-get install -y --force-yes postgresql-common=134wheezy3~bpo60+1+xivo+1 postgresql-client-common=134wheezy3~bpo60+1+xivo+1
fi

for package in $renamed_packages; do
    dpkg -l $package 2> /dev/null | grep -q '^ii'
    if [ $? = 0 ]; then
        apt-get purge $package > /dev/null
    fi
done
