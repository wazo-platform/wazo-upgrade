#!/bin/bash
# Copyright 2018-2020 The Wazo Authors  (see the AUTHORS file)
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

renamed_packages="xivo-confgend
                  xivo-confgend-client
                  xivo-dxtora
                  xivo-dxtorc
                  xivo-amid
                  xivo-amid-client
                  xivo-amid-client-python3
                  xivo-keyring
                  xivo-sounds-fr-fr
                  xivo-sounds-en-us
                  xivo-stat"

removed_packages=""

for package in $renamed_packages $removed_packages; do
    if is_package_purgeable $package; then
        apt-get purge -y $package
    fi
done

# migrate xivo-sounds which are installed manually
sounds_renamed_packages="xivo-sounds-fr-ca
                         xivo-sounds-de-de
                         xivo-sounds-nl-nl"
for old_package in $sounds_renamed_packages; do
    new_package=$(echo $old_package | sed 's/xivo/wazo/')
    if is_package_installed $old_package; then
        apt-get install -o Dpkg::Options::="--force-confnew" -y $new_package
        apt-get purge -y $old_package
    fi
done

# purge postgresql-X.X packages
if is_package_installed xivo-dbms; then
   if is_package_purgeable postgresql-9.6; then
       apt-get purge -y postgresql-9.6 postgresql-client-9.6 postgresql-plpython-9.6 postgresql-contrib-9.6
       systemctl restart postgresql.service
   fi
fi
