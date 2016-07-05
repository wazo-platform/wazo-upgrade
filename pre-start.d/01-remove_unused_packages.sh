#!/bin/bash

copy_new_files_while_preserving_old_files() {
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

is_package_installed() {
    [ "$(dpkg-query -W -f '${Status}' "$1" 2>/dev/null)" = 'install ok installed' ]
}

is_package_purgeable() {
    local output

    output="$(dpkg-query -W -f '${Status}' "$1" 2>/dev/null)"

    [ "$?" -eq 0 -a "$output" != 'unknown ok not-installed' ]
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
    if is_package_purgeable $package; then
        apt-get purge -y --force-yes $package
    fi
done

# manually purge xivo-manage-tokens
rm -rf /var/lib/xivo-manage-tokens

# purge postgresql-X.X packages
if is_package_installed xivo-dbms; then
   if is_package_purgeable postgresql-9.1; then
       apt-get purge -y --force-yes postgresql-9.1 postgresql-client-9.1 postgresql-plpython-9.1
   fi
fi
