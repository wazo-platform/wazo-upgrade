#!/usr/bin/env bats
# Copyright 2026 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

load ../test_helper

PACKAGE='wazo-plugind-wazo-prometheus-exporter-wazoplatform'

setup() {
	fake_root_setup
	stub_path_setup
	SCRIPT="$REPO_ROOT/pre-stop.d/10-remove-prometheus-exporter-plugin.sh"
	SENTINEL="$WAZO_UPGRADE_ROOT/var/lib/wazo-upgrade/remove-prometheus-exporter-plugin"
	export WAZO_VERSION_CANDIDATE='26.11'
	stub wazo-plugind-cli 0
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
