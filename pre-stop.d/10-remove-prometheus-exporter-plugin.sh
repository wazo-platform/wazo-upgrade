#!/bin/bash
# Copyright 2026 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
set -u  # fail if variable is undefined
set -o pipefail  # fail if command before pipe fails

SENTINEL="${WAZO_UPGRADE_ROOT:-}/var/lib/wazo-upgrade/remove-prometheus-exporter-plugin"
PLUGIN='wazoplatform/wazo-prometheus-exporter'
PACKAGE='wazo-plugind-wazo-prometheus-exporter-wazoplatform'
[ -f "$SENTINEL" ] && exit 0

# From 26.11, services ship their own plugin with the same `metrics` name
if dpkg --compare-versions "${WAZO_VERSION_CANDIDATE:?is not set}" lt 26.11; then
    exit 0
fi

if [ "$(dpkg-query -W -f '${Status}' "$PACKAGE" 2>/dev/null)" = 'install ok installed' ]; then
    echo "Uninstalling the $PLUGIN plugin"
    wazo-plugind-cli uninstall "$PLUGIN"
fi

touch "$SENTINEL"
