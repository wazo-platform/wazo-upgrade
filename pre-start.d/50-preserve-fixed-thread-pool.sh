#!/bin/bash
# Copyright 2026 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
set -u  # fail if variable is undefined
set -o pipefail  # fail if command before pipe fails

: ${SENTINEL:="/var/lib/wazo-upgrade/rename-rest-api-max-threads"}
: ${ETC_DIR:="/etc"}
[ -f "$SENTINEL" ] && exit 0

# rest_api.max_threads changed meaning: it used to be a fixed thread count
# and is now the ceiling of a demand-scaled pool. Rename custom max_threads
# to min_threads so tuned systems keep the same number of always-ready
# threads; the pool may additionally grow up to the new max_threads default.

SERVICES="wazo-agentd wazo-amid wazo-auth wazo-calld wazo-call-logd \
wazo-chatd wazo-confd wazo-dird wazo-phoned wazo-webhookd"

for service in $SERVICES; do
    conf_dir="${ETC_DIR}/${service}/conf.d"
    [ -d "$conf_dir" ] || continue
    for config_file in "$conf_dir"/*.yml; do
        [ -f "$config_file" ] || continue
        grep -qE '^ *max_threads:' "$config_file" || continue
        echo "Renaming max_threads to min_threads in ${config_file}"
        sed -i 's/^\( *\)max_threads:/\1min_threads:/' "$config_file"
    done
done

touch "$SENTINEL"
