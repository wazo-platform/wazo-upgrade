#!/usr/bin/env bats
# Copyright 2026 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

load test_helper

setup() {
	SCRIPT="$REPO_ROOT/bin/wazo-asterisk-custom-modules"
	export ASTERISK_MODULES_DIR="$BATS_TEST_TMPDIR/modules"
	export ASTERISK_MD5SUMS_FILE="$BATS_TEST_TMPDIR/asterisk.md5sums"
	mkdir -p "$ASTERISK_MODULES_DIR"
	: > "$ASTERISK_MD5SUMS_FILE"
}

# md5sums lines look like: <hash>  usr/lib/asterisk/modules/<name>.so
# The column layout matters: the script extracts the name with cut -c 60-
md5sums_line_for_module() {
	printf '0123456789abcdef0123456789abcdef  usr/lib/asterisk/modules/%s\n' "$1"
}

@test "reports nothing when every installed module is standard (dpkg-tracked)" {
	touch "$ASTERISK_MODULES_DIR/chan_sip.so"
	md5sums_line_for_module chan_sip.so > "$ASTERISK_MD5SUMS_FILE"

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "reports nothing when every installed module is an always-allowed extra" {
	touch "$ASTERISK_MODULES_DIR/chan_sccp.so"
	touch "$ASTERISK_MODULES_DIR/res_amqp.so"

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "reports an installed module that is neither dpkg-tracked nor an allowed extra" {
	touch "$ASTERISK_MODULES_DIR/chan_sip.so"
	touch "$ASTERISK_MODULES_DIR/codec_g729a.so"
	md5sums_line_for_module chan_sip.so > "$ASTERISK_MD5SUMS_FILE"

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ "$output" = 'codec_g729a.so' ]
}

@test "does not report a dpkg-tracked module that is not actually installed" {
	md5sums_line_for_module chan_sip.so > "$ASTERISK_MD5SUMS_FILE"

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "ignores non-.so files in the modules directory" {
	touch "$ASTERISK_MODULES_DIR/README.txt"

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ -z "$output" ]
}
