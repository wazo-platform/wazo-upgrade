#!/bin/bash

function copy_new_files_while_preserving_old_files () {
	old_dir="$1"
	new_dir="$2"
	backup_dir="$2.bak-xivo-upgrade"
	if [ -d "$old_dir" ]; then
		mv "$new_dir" "$backup_dir"
		mkdir "$new_dir"
		rsync -av --prune-empty-dirs "$old_dir/" "$new_dir/"
		rsync -rcbv --suffix=.dpkg-old "$backup_dir/" "$new_dir/"
		rm -rf "$old_dir"
		rm -rf "$backup_dir"
	fi
}

renamed_packages="pf-xivo-agid
                  pf-xivo-base-config
                  pf-xivo-fetchfw
                  pf-xivo-provd
                  pf-xivo-dxtora
                  pf-xivo-dhcpd-update
                  pf-xivo-monitoring
                  pf-xivo-web-interface
                  pf-xivo-web-interface-config
                  pf-xivo-sysconfd
                  xivo-agent
                  xivo-restapi"

echo "Cleaning up outdated config files..."
copy_new_files_while_preserving_old_files /etc/pf-xivo /etc/xivo

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
    dpkg -l $package 2> /dev/null | grep -Eq '^(ii|rc)'
    if [ $? = 0 ]; then
        apt-get purge -y --force-yes $package
    fi
done
