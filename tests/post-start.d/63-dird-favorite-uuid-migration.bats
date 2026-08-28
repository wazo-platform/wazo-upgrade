#!/usr/bin/env bats
# Copyright 2026 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later
#
# wazo-dird answers over a socket here, so the script's own retry, status
# handling and JSON parsing are what run. Only the wazo libraries it imports
# stand in, see wazo_lib_stubs/README.md.

setup() {
	load '../test_helper'
	fake_root_setup
	stub_path_setup

	mkdir -p "$WAZO_UPGRADE_ROOT/etc/wazo-dird/conf.d"
	stub systemctl 0

	script="$REPO_ROOT/post-start.d/63-dird-favorite-uuid-migration.py"
	sentinel="$WAZO_UPGRADE_ROOT/var/lib/wazo-upgrade/dird-favorite-uuid-migration"
	conf_file="$WAZO_UPGRADE_ROOT/etc/wazo-dird/conf.d/20-wazo-upgrade-favorite-migration.yml"

	dird_calls="$BATS_TEST_TMPDIR/dird-calls"
	dird_status="$BATS_TEST_TMPDIR/dird-status"
	dird_body="$BATS_TEST_TMPDIR/dird-body"
	given_dird_replies 200 '{"migrated": 2, "already_migrated": 0,
		"deduplicated": 0, "dropped": 0, "failed_sources": 0, "sources": []}'

	start_dird
	export PYTHONPATH="$BATS_TEST_DIRNAME/wazo_lib_stubs"
}

teardown() {
	[ -n "${dird_pid:-}" ] && kill "$dird_pid" 2>/dev/null
	return 0
}

# The reply is read per request, so a test can change it after the mock started
given_dird_replies() {
	echo "$1" > "$dird_status"
	echo "$2" > "$dird_body"
}

start_dird() {
	# a free port rather than 9489: the suite must not need a port to itself
	export FAKE_DIRD_PORT=$(python3 -c 'import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()')

	python3 "$BATS_TEST_DIRNAME/dird_mock.py" \
		"$FAKE_DIRD_PORT" "$dird_calls" "$dird_status" "$dird_body" &
	dird_pid=$!

	for _ in $(seq 50); do
		if python3 -c "
import socket, sys
s = socket.socket()
sys.exit(0 if s.connect_ex(('127.0.0.1', $FAKE_DIRD_PORT)) == 0 else 1)"; then
			return 0
		fi
		sleep 0.1
	done
	echo "the wazo-dird mock never came up" >&2
	return 1
}

@test "it does nothing when the migration already ran" {
	touch "$sentinel"

	run "$script"

	[ "$status" -eq 0 ]
	[ ! -f "$dird_calls" ]
	[ "$(stub_call_count systemctl)" -eq 0 ]
}

@test "--force runs it again, as the migration is idempotent" {
	touch "$sentinel"

	run "$script" --force

	[ "$status" -eq 0 ]
	grep -q 'favorite_migration' "$dird_calls"
}

@test "it calls the migration endpoint and leaves the sentinel behind" {
	run "$script"

	[ "$status" -eq 0 ]
	grep -q '/0.1/favorite_migration' "$dird_calls"
	[ -f "$sentinel" ]
}

@test "it enables the plugin through conf.d and removes it afterwards" {
	run "$script"

	[ "$status" -eq 0 ]
	# the endpoint must not outlive the migration
	[ ! -f "$conf_file" ]
	# twice: once to enable the plugin, once to take it away again
	[ "$(stub_call_count systemctl)" -eq 2 ]
}

@test "it fails and keeps no sentinel when wazo-dird refuses the migration" {
	given_dird_replies 500 '{}'

	run "$script"

	[ "$status" -eq 2 ]
	# the next upgrade has to try again
	[ ! -f "$sentinel" ]
	[ ! -f "$conf_file" ]
}

@test "it fails when a source could not be migrated" {
	given_dird_replies 200 '{"migrated": 0, "already_migrated": 0,
		"deduplicated": 0, "dropped": 0, "failed_sources": 1,
		"sources": [{"source_name": "wazo_america", "dropped": [],
		"error": "confd unreachable"}]}'

	run "$script"

	[ "$status" -eq 2 ]
	[ ! -f "$sentinel" ]
}

@test "it reports the favorites the migration dropped" {
	given_dird_replies 200 '{"migrated": 0, "already_migrated": 0,
		"deduplicated": 0, "dropped": 1, "failed_sources": 0,
		"sources": [{"source_name": "wazo_america", "error": null,
		"dropped": [{"contact_id": "226", "user_uuid": "a-user"}]}]}'

	run "$script"

	[ "$status" -eq 0 ]
	# deleting a favorite must leave a trace naming it
	[[ "$output" == *"226"* ]]
	[[ "$output" == *"deleted"* ]]
}
