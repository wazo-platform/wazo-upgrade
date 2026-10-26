#!/usr/bin/env bats
# Copyright 2026 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

load ../test_helper

PACKAGE='wazo-plugind-wazo-prometheus-exporter-wazoplatform'
SERVICES="wazo-agentd wazo-amid wazo-auth wazo-calld wazo-call-logd \
wazo-chatd wazo-confd wazo-dird wazo-phoned wazo-webhookd"

setup() {
	fake_root_setup
	stub_path_setup
	SCRIPT="$REPO_ROOT/pre-stop.d/10-remove-prometheus-exporter-plugin.sh"
	SENTINEL="$WAZO_UPGRADE_ROOT/var/lib/wazo-upgrade/remove-prometheus-exporter-plugin"
	export WAZO_VERSION_CANDIDATE='26.11'
	for service in $SERVICES; do
		mkdir -p "$WAZO_UPGRADE_ROOT/etc/$service/conf.d"
	done
	mkdir -p "$WAZO_UPGRADE_ROOT/etc/asterisk"
	ASTERISK_DROP_IN="$WAZO_UPGRADE_ROOT/etc/asterisk/prometheus.d/50-enable-metrics.conf"
	stub wazo-plugind-cli 0
}

drop_in() {
	echo "$WAZO_UPGRADE_ROOT/etc/$1/conf.d/50-enable-metrics.yml"
}

drop_in_count() {
	find "$WAZO_UPGRADE_ROOT/etc" -name 50-enable-metrics.yml | wc -l
}

plugin_installed() {
	stub dpkg-query 0 'install ok installed'
}

plugin_not_installed() {
	stub dpkg-query 1
}

@test "uninstalls the plugin through wazo-plugind and writes the sentinel" {
	plugin_installed

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	grep -q "dpkg-query -W -f \${Status} $PACKAGE" "$STUB_DIR/dpkg-query.calls"
	grep -q 'wazo-plugind-cli uninstall wazoplatform/wazo-prometheus-exporter' \
		"$STUB_DIR/wazo-plugind-cli.calls"
	[ -f "$SENTINEL" ]
}

@test "writes the sentinel without uninstalling when the plugin is not installed" {
	plugin_not_installed

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ "$(stub_call_count wazo-plugind-cli)" -eq 0 ]
	[ -f "$SENTINEL" ]
}

@test "fails and writes no sentinel when the uninstall fails" {
	plugin_installed
	stub wazo-plugind-cli 1

	run "$SCRIPT"

	[ "$status" -ne 0 ]
	[ ! -f "$SENTINEL" ]
}

@test "keeps the plugin when upgrading to a version before 26.11" {
	plugin_installed
	export WAZO_VERSION_CANDIDATE='26.10'

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ "$(stub_call_count wazo-plugind-cli)" -eq 0 ]
	[ ! -f "$SENTINEL" ]
}

@test "removes the plugin when upgrading past 26.11" {
	plugin_installed
	export WAZO_VERSION_CANDIDATE='27.01'

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ "$(stub_call_count wazo-plugind-cli)" -eq 1 ]
	[ -f "$SENTINEL" ]
}

@test "does nothing once the sentinel exists" {
	plugin_installed
	touch "$SENTINEL"

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ "$(stub_call_count dpkg-query)" -eq 0 ]
	[ "$(stub_call_count wazo-plugind-cli)" -eq 0 ]
}

@test "fails when the target version is unknown" {
	plugin_installed
	unset WAZO_VERSION_CANDIDATE

	run "$SCRIPT"

	[ "$status" -ne 0 ]
	[ "$(stub_call_count wazo-plugind-cli)" -eq 0 ]
	[ ! -f "$SENTINEL" ]
}

@test "enables the metrics plugin of every service when the plugin was installed" {
	plugin_installed

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ "$(drop_in_count)" -eq 10 ]
	[ "$(grep -v '^#' "$(drop_in wazo-calld)")" = "$(printf 'enabled_plugins:\n  metrics: true')" ]
	[ "$(grep -v '^#' "$(drop_in wazo-phoned)")" = "$(printf 'enabled_plugins:\n  metrics: true')" ]
	[ "$(grep -v '^#' "$(drop_in wazo-dird)")" = "$(printf 'enabled_plugins:\n  views:\n    metrics: true')" ]
	[ "$(grep -v '^#' "$(drop_in wazo-auth)")" = "$(printf 'enabled_http_plugins:\n  metrics: true')" ]
}

@test "keeps the drop-ins when the uninstall fails, for the retry" {
	plugin_installed
	stub wazo-plugind-cli 1

	run "$SCRIPT"

	[ "$status" -ne 0 ]
	[ "$(drop_in_count)" -eq 10 ]
	[ ! -f "$SENTINEL" ]
}

@test "enables nothing when the plugin was not installed" {
	plugin_not_installed

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ "$(drop_in_count)" -eq 0 ]
}

@test "enables nothing when upgrading to a version before 26.11" {
	plugin_installed
	export WAZO_VERSION_CANDIDATE='26.10'

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ "$(drop_in_count)" -eq 0 ]
}

@test "skips a service without a configuration directory" {
	plugin_installed
	rm -r "$WAZO_UPGRADE_ROOT/etc/wazo-chatd"

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ "$(drop_in_count)" -eq 9 ]
	[ ! -e "$WAZO_UPGRADE_ROOT/etc/wazo-chatd" ]
}

@test "enables the Asterisk metrics when the plugin was installed" {
	plugin_installed

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ "$(grep -v '^;' "$ASTERISK_DROP_IN")" = "$(printf '[general](+)\nenabled = yes')" ]
}

@test "enables no Asterisk metrics when the plugin was not installed" {
	plugin_not_installed

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ ! -e "$ASTERISK_DROP_IN" ]
}

@test "skips the Asterisk metrics when Asterisk is not configured" {
	plugin_installed
	rm -r "$WAZO_UPGRADE_ROOT/etc/asterisk"

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ ! -e "$WAZO_UPGRADE_ROOT/etc/asterisk" ]
	[ "$(drop_in_count)" -eq 10 ]
}
