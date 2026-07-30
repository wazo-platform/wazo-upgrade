#!/usr/bin/env bats
# Copyright 2026 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

load ../test_helper

setup() {
	export ETC_DIR="$BATS_TEST_TMPDIR/etc"
	export SENTINEL="$BATS_TEST_TMPDIR/var/lib/wazo-upgrade/rename-rest-api-max-threads"
	mkdir -p "$ETC_DIR" "$(dirname "$SENTINEL")"
	SCRIPT="$REPO_ROOT/pre-start.d/50-preserve-fixed-thread-pool.sh"
}

write_conf() {
	local service=$1 name=$2 content=$3
	mkdir -p "$ETC_DIR/$service/conf.d"
	printf '%s\n' "$content" > "$ETC_DIR/$service/conf.d/$name.yml"
}

@test "renames a custom max_threads to min_threads and creates the sentinel" {
	write_conf wazo-confd 10-custom $'rest_api:\n  max_threads: 42'

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[[ "$output" == *'Renaming max_threads to min_threads'* ]]
	[ "$(cat "$ETC_DIR/wazo-confd/conf.d/10-custom.yml")" = $'rest_api:\n  min_threads: 42' ]
	[ -f "$SENTINEL" ]
}

@test "leaves configs alone that do not set max_threads" {
	write_conf wazo-confd 10-custom $'rest_api:\n  debug: true'

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[[ "$output" != *Renaming* ]]
	[ "$(cat "$ETC_DIR/wazo-confd/conf.d/10-custom.yml")" = $'rest_api:\n  debug: true' ]
}

@test "processes every service directory that has conf.d files" {
	write_conf wazo-confd 10-custom $'rest_api:\n  max_threads: 5'
	write_conf wazo-calld 10-custom $'rest_api:\n  max_threads: 8'

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	grep -q 'min_threads: 5' "$ETC_DIR/wazo-confd/conf.d/10-custom.yml"
	grep -q 'min_threads: 8' "$ETC_DIR/wazo-calld/conf.d/10-custom.yml"
}

@test "does nothing for a service with no conf.d directory" {
	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[[ "$output" != *Renaming* ]]
	[ -f "$SENTINEL" ]
}

@test "is a no-op when the sentinel is already present" {
	write_conf wazo-confd 10-custom $'rest_api:\n  max_threads: 42'
	touch "$SENTINEL"
	local before
	before="$(md5sum "$ETC_DIR/wazo-confd/conf.d/10-custom.yml")"

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ -z "$output" ]
	[ "$(md5sum "$ETC_DIR/wazo-confd/conf.d/10-custom.yml")" = "$before" ]
}

@test "does not touch a service whose config never mentions max_threads" {
	write_conf wazo-confd 10-custom $'rest_api:\n  max_threads: 42'
	write_conf wazo-auth 10-custom $'rest_api:\n  debug: true'

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ "$(cat "$ETC_DIR/wazo-auth/conf.d/10-custom.yml")" = $'rest_api:\n  debug: true' ]
}
