#!/bin/bash
# Copyright 2018 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0+

is_package_installed() {
    [ "$(dpkg-query -W -f '${Status}' "$1" 2>/dev/null)" = 'install ok installed' ]
}

is_package_purgeable() {
    local output

    output="$(dpkg-query -W -f '${Status}' "$1" 2>/dev/null)"

    [ "$?" -eq 0 -a "$output" != 'unknown ok not-installed' ]
}

renamed_packages="xivo-call-logs
                  xivo-dird
                  xivo-restapi"

for package in $renamed_packages; do
    if is_package_purgeable $package; then
        apt-get purge -y --force-yes $package
    fi
done

# purge postgresql-X.X packages
if is_package_installed xivo-dbms; then
   if is_package_purgeable postgresql-9.4; then
       apt-get purge -y --force-yes postgresql-9.4 postgresql-client-9.4 postgresql-plpython-9.4 postgresql-contrib-9.4
       systemctl restart postgresql.service
   fi
fi

# purge php5-common
if ! is_package_installed php5-common; then
    if is_package_purgeable php5-common; then
       apt-get purge -y --force-yes php5-common
    fi
fi
