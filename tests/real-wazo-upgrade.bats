#!/usr/bin/env bats
# Copyright 2026 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

load test_helper

setup() {
	stub_path_setup
	source_real_wazo_upgrade
	# real-wazo-upgrade hard-resets PATH to trusted system dirs; re-prepend
	# the stub dir now that sourcing is done
	PATH="$STUB_DIR:$PATH"
}

@test "run_upgrade_scripts runs scripts in lexical order" {
	make_phase_script pre-start 20-second.sh
	make_phase_script pre-start 10-first.sh

	run_upgrade_scripts pre-start

	[ "$(recorded_calls)" = "$(printf '10-first.sh\n20-second.sh')" ]
}

@test "run_upgrade_scripts stops at the first failure and records the script" {
	make_phase_script pre-start 10-ok.sh
	make_phase_script pre-start 20-fail.sh 1
	make_phase_script pre-start 30-after.sh

	local result=0
	run_upgrade_scripts pre-start || result=$?

	[ "$result" -ne 0 ]
	[ "$failed_script" = "$lib_directory/pre-start.d/20-fail.sh" ]
	[[ "$(recorded_calls)" != *30-after.sh* ]]
}

@test "run_upgrade_scripts succeeds when the phase directory is empty" {
	mkdir -p "$lib_directory/pre-start.d"

	run_upgrade_scripts pre-start
}

@test "run_upgrade_scripts succeeds when the phase directory is missing" {
	run_upgrade_scripts pre-start
}

@test "pre_stop failure aborts without restarting wazo" {
	make_phase_script pre-stop 10-fail.sh 1
	stub wazo-service 0

	run pre_stop

	[ "$status" -ne 0 ]
	[[ "$output" == *"Failed to execute"* ]]
	[[ "$output" == *10-fail.sh* ]]
	[ ! -f "$STUB_DIR/wazo-service.calls" ]
}

@test "post_stop failure restarts wazo before aborting" {
	make_phase_script post-stop 10-fail.sh 1
	stub wazo-service 0

	run post_stop

	[ "$status" -ne 0 ]
	[[ "$output" == *"Failed to execute"* ]]
	grep -q 'wazo-service enable' "$STUB_DIR/wazo-service.calls"
	grep -q 'wazo-service restart' "$STUB_DIR/wazo-service.calls"
}

@test "pre_start failure restarts wazo and reports a partial upgrade" {
	make_phase_script pre-start 10-fail.sh 1
	stub wazo-service 0

	run pre_start

	[ "$status" -ne 0 ]
	[[ "$output" == *"The system is only partially upgraded"* ]]
	grep -q 'wazo-service enable' "$STUB_DIR/wazo-service.calls"
	grep -q 'wazo-service restart' "$STUB_DIR/wazo-service.calls"
}

@test "post_start runs every script even after a failure" {
	make_phase_script post-start 10-fail.sh 1
	make_phase_script post-start 20-after.sh

	run post_start

	[ "$status" -eq 0 ]
	[[ "$(recorded_calls)" == *20-after.sh* ]]
	# only the failing script is named on the summary line
	local summary
	summary=$(grep 'Failed to execute the following scripts:' <<< "$output")
	[ "$summary" = "Failed to execute the following scripts: $lib_directory/post-start.d/10-fail.sh" ]
}

@test "post_start prints nothing when every script succeeds" {
	make_phase_script post-start 10-ok.sh

	run post_start

	[ "$status" -eq 0 ]
	[[ "$output" != *WARNING* ]]
}

@test "executing the script directly still reaches main" {
	# The other tests source the script, which only proves main() is
	# suppressed on source; this proves the other half of the guard
	run "$REPO_ROOT/bin/real-wazo-upgrade" -h

	[ "$status" -eq 0 ]
	[[ "$output" == *"usage: wazo-upgrade"* ]]
}

@test "upgrade removes the incomplete marker on success" {
	stub_upgrade_environment

	upgrade

	[ ! -f "$upgrade_incomplete_file" ]
}

@test "upgrade keeps the incomplete marker when a pre-start script fails" {
	stub_upgrade_environment
	make_phase_script pre-start 10-fail.sh 1

	run upgrade

	[ "$status" -ne 0 ]
	[ -f "$upgrade_incomplete_file" ]
}

@test "upgrade keeps the incomplete marker when services fail to start" {
	stub_upgrade_environment
	start_wazo() { return 1; }

	run upgrade

	[ "$status" -ne 0 ]
	[ -f "$upgrade_incomplete_file" ]
}
