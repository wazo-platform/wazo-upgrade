#!/bin/bash
# Copyright 2018-2023 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
set -u  # fail if variable is undefined
set -o pipefail  # fail if command before pipe fails

is_package_installed() {
    [ "$(dpkg-query -W -f '${Status}' "$1" 2>/dev/null)" = 'install ok installed' ]
}

is_package_purgeable() {
    local output

    output="$(dpkg-query -W -f '${Status}' "$1" 2>/dev/null)"

    [ "$?" -eq 0 -a "$output" != 'unknown ok not-installed' ]
}

renamed_packages=""

removed_packages=""

for package in $renamed_packages $removed_packages; do
    if is_package_purgeable $package; then
        apt-get purge -y $package
    fi
done

# purge postgresql-XX packages
if is_package_installed wazo-dbms; then
   if is_package_purgeable postgresql-plpython-11; then
       apt-get purge -y postgresql-plpython-11
   fi
   if is_package_purgeable postgresql-11; then
       apt-get purge -y postgresql-11 postgresql-client-11 postgresql-contrib-11
       systemctl restart postgresql.service
   fi
fi
