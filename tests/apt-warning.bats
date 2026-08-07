#!/usr/bin/env bats
# Copyright 2026 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

load test_helper

setup() {
	stub_path_setup
	SCRIPT="$REPO_ROOT/bin/apt-warning"
}

@test "apt-warning passes through non-upgrade actions without prompting" {
	stub apt 0

	run bash -c "printf '' | '$SCRIPT' install foo"

	[ "$status" -eq 0 ]
	[[ "$output" != *WARNING* ]]
	[ "$(stub_call_count apt)" -eq 1 ]
	grep -q 'install foo' "$STUB_DIR/apt.calls"
}

@test "apt-warning warns and proceeds on 'y' for upgrade" {
	stub apt 0

	run bash -c "printf 'y\n' | '$SCRIPT' upgrade"

	[ "$status" -eq 0 ]
	[[ "$output" == *"WARNING: This command is not supported"* ]]
	[ "$(stub_call_count apt)" -eq 1 ]
}

@test "apt-warning warns and proceeds on 'Y' for dist-upgrade" {
	stub apt 0

	run bash -c "printf 'Y\n' | '$SCRIPT' dist-upgrade"

	[ "$status" -eq 0 ]
	[ "$(stub_call_count apt)" -eq 1 ]
}

@test "apt-warning warns and proceeds on 'y' for full-upgrade" {
	stub apt 0

	run bash -c "printf 'y\n' | '$SCRIPT' full-upgrade"

	[ "$status" -eq 0 ]
	[ "$(stub_call_count apt)" -eq 1 ]
}

@test "apt-warning aborts on explicit 'n' for upgrade" {
	stub apt 0

	run bash -c "printf 'n\n' | '$SCRIPT' upgrade"

	[ "$status" -eq 1 ]
	[ ! -f "$STUB_DIR/apt.calls" ]
}

@test "apt-warning defaults to 'N' (abort) when answer is empty" {
	stub apt 0

	run bash -c "printf '\n' | '$SCRIPT' upgrade"

	[ "$status" -eq 1 ]
	[ ! -f "$STUB_DIR/apt.calls" ]
}

@test "apt-warning forwards apt's exit status for non-warning actions" {
	stub apt 42

	run bash -c "printf '' | '$SCRIPT' list foo"

	[ "$status" -eq 42 ]
}
