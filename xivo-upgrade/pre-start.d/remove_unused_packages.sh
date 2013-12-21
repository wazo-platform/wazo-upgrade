#!/bin/bash
old_fais="pf-fai pf-fai-dev pf-fai-xivo-1.2-skaro pf-fai-xivo-1.2-skaro-dev"
renamed_packages="pf-xivo-agid pf-xivo-base-config pf-xivo-fetchfw pf-xivo-web-interface-config pf-xivo-provd pf-xivo-dxtora pf-xivo-dhcpd-update pf-xivo-monitoring pf-xivo-web-interface pf-xivo-sysconfd"
postrm_webi_config="/var/lib/dpkg/info/pf-xivo-web-interface-config.postrm"

echo "cleanup outdated config files"
if [ -f $postrm_webi_config ]; then
    rsync -av /etc/pf-xivo/web-interface /tmp/ > /dev/null
    rm -rf $postrm_webi_config > /dev/null
fi

# cleanup pf-xivo-base-config.postrm file to allow package purge
base_config_postrm="/var/lib/dpkg/info/pf-xivo-base-config.postrm"
xivo_config_postrm="/var/lib/dpkg/info/xivo-config.postrm"
if [ -f $base_config_postrm ]; then
    rsync -av /etc/pf-xivo/web-interface /tmp/ > /dev/null
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
    /etc/init.d/xivo-provd restart
fi

# remove old postgresql-common and postgresql-client-common
pg_common_version=$(LANG=C apt-cache policy postgresql-common | grep Installed | awk '{print $2}')
if [ "$pg_common_version" = "140+0.xivo-backport-2" ]; then
    apt-get install -y --force-yes postgresql-common=134wheezy3~bpo60+1+xivo+1 postgresql-client-common=134wheezy3~bpo60+1+xivo+1
fi

old_web_interface_log_directory="/var/log/pf-xivo-web-interface"
old_web_interface_config_directory="/etc/pf-xivo/web-interface"

for dir in $old_web_interface_log_directory $old_web_interface_config_directory; do
    if [ -d $dir ]; then
        rm -rf $dir
    fi
done
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

if [ -d /tmp/web-interface ]; then
    rsync -av /tmp/web-interface/ /etc/pf-xivo/web-interface/ > /dev/null
    rm -rf /tmp/web-interface > /dev/null
fi
