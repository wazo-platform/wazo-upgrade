#!/bin/bash
# Copyright 2026 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
set -u  # fail if variable is undefined
set -o pipefail  # fail if command before pipe fails

SENTINEL="${WAZO_UPGRADE_ROOT:-}/var/lib/wazo-upgrade/remove-prometheus-exporter-plugin"
ETC_DIR="${WAZO_UPGRADE_ROOT:-}/etc"
PLUGIN='wazoplatform/wazo-prometheus-exporter'
PACKAGE='wazo-plugind-wazo-prometheus-exporter-wazoplatform'
SERVICES="wazo-agentd wazo-amid wazo-auth wazo-calld wazo-call-logd \
wazo-chatd wazo-confd wazo-dird wazo-phoned wazo-webhookd"
[ -f "$SENTINEL" ] && exit 0

enable_metrics_plugin() {
    local service=$1
    local conf_dir="${ETC_DIR}/${service}/conf.d"
    [ -d "$conf_dir" ] || return 0
    echo "Enabling the metrics plugin of ${service}"
    {
        echo '# Created by wazo-upgrade: replaces the wazo-prometheus-exporter plugin'
        case "$service" in
            wazo-auth) printf 'enabled_http_plugins:\n  metrics: true\n' ;;
            wazo-dird) printf 'enabled_plugins:\n  views:\n    metrics: true\n' ;;
            *) printf 'enabled_plugins:\n  metrics: true\n' ;;
        esac
    } > "${conf_dir}/50-enable-metrics.yml"
}

enable_asterisk_metrics() {
    [ -d "${ETC_DIR}/asterisk" ] || return 0
    echo 'Enabling the Asterisk metrics'
    # Created before the wazo-asterisk-config version that includes this directory
    mkdir -p "${ETC_DIR}/asterisk/prometheus.d"
    printf '; Created by wazo-upgrade: replaces the wazo-prometheus-exporter plugin\n[general](+)\nenabled = yes\n' \
        > "${ETC_DIR}/asterisk/prometheus.d/50-enable-metrics.conf"
}

# From 26.11, services ship their own plugin with the same `metrics` name
if dpkg --compare-versions "${WAZO_VERSION_CANDIDATE:?is not set}" lt 26.11; then
    exit 0
fi

if [ "$(dpkg-query -W -f '${Status}' "$PACKAGE" 2>/dev/null)" = 'install ok installed' ]; then
    # Before the uninstall: a retry after a failed uninstall rewrites them
    for service in $SERVICES; do
        enable_metrics_plugin "$service"
    done
    enable_asterisk_metrics
    echo "Uninstalling the $PLUGIN plugin"
    wazo-plugind-cli uninstall "$PLUGIN"
fi

touch "$SENTINEL"
