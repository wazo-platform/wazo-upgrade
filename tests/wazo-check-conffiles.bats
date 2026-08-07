#!/usr/bin/env bats
# Copyright 2026 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

load test_helper

setup() {
	fake_root_setup
	mkdir -p "$BATS_TEST_TMPDIR/etc/xivo"

	source "$REPO_ROOT/bin/wazo-check-conffiles"
	: > "$XIVO_CONFIG_CONFFILES_LIST"
	: > "$SYSTEMD_SYSTEM_CONF"
}

@test "list_modified_conffiles reports nothing when no .dpkg-old backups exist" {
	echo "$BATS_TEST_TMPDIR/etc/xivo/ring.conf" > "$XIVO_CONFIG_CONFFILES_LIST"

	run list_modified_conffiles

	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "list_modified_conffiles reports a conffile that dpkg overwrote" {
	echo "$BATS_TEST_TMPDIR/etc/xivo/ring.conf" > "$XIVO_CONFIG_CONFFILES_LIST"
	touch "$BATS_TEST_TMPDIR/etc/xivo/ring.conf.dpkg-old"

	run list_modified_conffiles

	[ "$status" -eq 0 ]
	[ "$output" = "$BATS_TEST_TMPDIR/etc/xivo/ring.conf" ]
}

@test "list_modified_conffiles also checks the systemd system.conf" {
	touch "${SYSTEMD_SYSTEM_CONF}.dpkg-old"

	run list_modified_conffiles

	[ "$status" -eq 0 ]
	[ "$output" = "$SYSTEMD_SYSTEM_CONF" ]
}

@test "list_modified_conffiles removes an ignored .dpkg-old and does not report it" {
	echo "$BATS_TEST_TMPDIR/etc/xivo/ring.conf" > "$XIVO_CONFIG_CONFFILES_LIST"
	echo -n 'stale backup' > "$BATS_TEST_TMPDIR/etc/xivo/ring.conf.dpkg-old"
	IGNORE_LIST="$(md5sum "$BATS_TEST_TMPDIR/etc/xivo/ring.conf.dpkg-old")"

	run list_modified_conffiles

	[ "$status" -eq 0 ]
	[ -z "$output" ]
	[ ! -f "$BATS_TEST_TMPDIR/etc/xivo/ring.conf.dpkg-old" ]
}

@test "is_conffile_old_ignored succeeds when the file's md5sum is in IGNORE_LIST" {
	echo -n 'stale backup' > "$BATS_TEST_TMPDIR/old.dpkg-old"
	IGNORE_LIST="$(md5sum "$BATS_TEST_TMPDIR/old.dpkg-old")"

	run is_conffile_old_ignored "$BATS_TEST_TMPDIR/old.dpkg-old"

	[ "$status" -eq 0 ]
}

@test "is_conffile_old_ignored fails when IGNORE_LIST is empty" {
	echo -n 'stale backup' > "$BATS_TEST_TMPDIR/old.dpkg-old"

	run is_conffile_old_ignored "$BATS_TEST_TMPDIR/old.dpkg-old"

	[ "$status" -ne 0 ]
}

@test "main prints a warning naming the modified files when any were overwritten" {
	echo "$BATS_TEST_TMPDIR/etc/xivo/ring.conf" > "$XIVO_CONFIG_CONFFILES_LIST"
	touch "$BATS_TEST_TMPDIR/etc/xivo/ring.conf.dpkg-old"

	run main

	[ "$status" -eq 0 ]
	[[ "$output" == *"WARNING: The following configuration files were overwritten"* ]]
	[[ "$output" == *"$BATS_TEST_TMPDIR/etc/xivo/ring.conf"* ]]
	[[ "$output" == *'vimdiff FILENAME FILENAME.dpkg-old'* ]]
}

@test "main prints nothing when no conffiles were overwritten" {
	echo "$BATS_TEST_TMPDIR/etc/xivo/ring.conf" > "$XIVO_CONFIG_CONFFILES_LIST"

	run main

	[ "$status" -eq 0 ]
	[ -z "$output" ]
}
