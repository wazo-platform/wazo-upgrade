#!/bin/bash
# Copyright 2018-2026 The Wazo Authors  (see the AUTHORS file)
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

renamed_packages="xivo-certs xivo-sync"

removed_packages="xivo-swagger-doc"

for package in $renamed_packages $removed_packages; do
    if is_package_purgeable $package; then
        # best-effort cleanup: a failed purge must not abort the upgrade
        apt-get purge -y $package || echo "WARNING: could not purge $package"
    fi
done

# purge postgresql-XX packages
if is_package_installed wazo-dbms; then
    if is_package_purgeable postgresql-13; then
        # The purge is not atomic: the restart must not depend on its success
        apt-get purge -y postgresql-13 postgresql-client-13 postgresql-contrib-13 \
            || echo "WARNING: could not purge all postgresql-13 packages"
        systemctl restart postgresql.service
    fi
fi
