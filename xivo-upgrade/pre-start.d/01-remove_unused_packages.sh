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

if [ -d /etc/pf-xivo ]; then
	rsync -av /etc/pf-xivo/ /etc/xivo/
	rm -rf /etc/pf-xivo
fi

# cleanup pf-xivo-base-config.postrm file to allow package purge
base_config_postrm="/var/lib/dpkg/info/pf-xivo-base-config.postrm"
xivo_config_postrm="/var/lib/dpkg/info/xivo-config.postrm"
if [ -f $base_config_postrm ]; then
    cp $xivo_config_postrm $base_config_postrm
    sed -i 's/xivo-config/pf-xivo-base-config/' $base_config_postrm
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
