#!/bin/bash
# Copyright 2026 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
set -u
set -o pipefail

CONFIGS_DIR=/var/lib/wazo-provd/jsondb/configs

# Configs created by the wazo-confd wizard that must remain non-deletable.
WIZARD_CONFIGS="base default defaultconfigdevice autoprov"

if [ -d "${CONFIGS_DIR}" ]; then
    for config_id in ${WIZARD_CONFIGS}; do
        config_file="${CONFIGS_DIR}/${config_id}"
        [ -f "${config_file}" ] || continue
        if [ "$(jq -r '.deletable' "${config_file}")" != "false" ]; then
            echo "Restoring deletable=false on ${config_file}"
            tmp_file="$(mktemp --tmpdir="${CONFIGS_DIR}" ".${config_id}.XXXXXX")"
            jq -c '.deletable = false' "${config_file}" > "${tmp_file}"
            chown --reference="${config_file}" "${tmp_file}"
            chmod --reference="${config_file}" "${tmp_file}"
            mv "${tmp_file}" "${config_file}"
        fi
    done
fi
