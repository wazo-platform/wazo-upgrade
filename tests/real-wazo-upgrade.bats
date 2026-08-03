#!/usr/bin/env bats
# Copyright 2026 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

load test_helper

setup() {
	stub_path_setup
	source_real_wazo_upgrade
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

@test "check_database_migration_is_enabled aborts when xivo-manage-db/db-skip is true" {
	stub debconf-show 0 '* xivo-manage-db/db-skip: true'

	run check_database_migration_is_enabled

	[ "$status" -eq 1 ]
	[[ "$output" == *'ERROR: database migrations are disabled (xivo-manage-db/db-skip is "true")'* ]]
}

@test "check_database_migration_is_enabled aborts when wazo-auth/db-skip is true" {
	stub debconf-show 0 '* wazo-auth/db-skip: true'

	run check_database_migration_is_enabled

	[ "$status" -eq 1 ]
	[[ "$output" == *'(wazo-auth/db-skip is "true")'* ]]
}

@test "check_database_migration_is_enabled passes when db-skip is false" {
	stub debconf-show 0 '* xivo-manage-db/db-skip: false'

	run check_database_migration_is_enabled

	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "check_wizard_has_been_run is skipped when resuming a failed upgrade" {
	resuming_failed_upgrade=1
	stub systemctl 1

	run check_wizard_has_been_run

	[ "$status" -eq 0 ]
	[ ! -f "$STUB_DIR/systemctl.calls" ]
}

@test "check_wizard_has_been_run aborts when wazo-confd is not running" {
	resuming_failed_upgrade=0
	stub systemctl 1

	run check_wizard_has_been_run

	[ "$status" -eq 1 ]
	[[ "$output" == *'wazo-confd is not running'* ]]
}

@test "check_wizard_has_been_run passes when the wizard has been run" {
	resuming_failed_upgrade=0
	stub systemctl 0
	stub curl 0 '{"configured": true}'

	run check_wizard_has_been_run

	[ "$status" -eq 0 ]
}

@test "check_wizard_has_been_run aborts when the wizard has not been run" {
	resuming_failed_upgrade=0
	stub systemctl 0
	stub curl 0 '{"configured": false}'

	run check_wizard_has_been_run

	[ "$status" -eq 1 ]
	[[ "$output" == *'You must configure Wazo'* ]]
}

@test "main flags a resumed upgrade when the incomplete marker exists" {
	check_database_migration_is_enabled() { :; }
	check_wizard_has_been_run() { :; }
	upgrading_system() { echo "resuming=$resuming_failed_upgrade"; }
	touch "$upgrade_incomplete_file"

	run main -f

	[ "$status" -eq 0 ]
	[[ "$output" == *'resuming=1'* ]]
}

@test "main does not flag a resumed upgrade without the incomplete marker" {
	check_database_migration_is_enabled() { :; }
	check_wizard_has_been_run() { :; }
	upgrading_system() { echo "resuming=$resuming_failed_upgrade"; }

	run main -f

	[ "$status" -eq 0 ]
	[[ "$output" == *'resuming=0'* ]]
}

@test "main -f skips the confirmation prompt" {
	check_database_migration_is_enabled() { :; }
	check_wizard_has_been_run() { :; }
	upgrade() { echo 'upgrade started'; }
	stub apt-cache 0
	stub dpkg-query 0 '8:22.1.0'
	stub dpkg 1

	# 'n' on stdin: only a skipped prompt lets the upgrade start
	run main -f <<< 'n'

	[ "$status" -eq 0 ]
	[[ "$output" == *'upgrade started'* ]]
}

@test "main without -f aborts when the answer is not yes" {
	check_database_migration_is_enabled() { :; }
	check_wizard_has_been_run() { :; }
	upgrade() { echo 'upgrade started'; }
	stub apt-cache 0
	stub dpkg-query 0 '8:22.1.0'
	stub dpkg 1

	run main <<< 'n'

	[ "$status" -eq 0 ]
	[[ "$output" != *'upgrade started'* ]]
}

@test "main -d only downloads packages" {
	check_database_migration_is_enabled() { :; }
	check_wizard_has_been_run() { :; }
	upgrading_system() { echo 'upgrading_system called'; }
	stub apt-get 0

	run main -d

	[ "$status" -eq 0 ]
	[[ "$output" != *'upgrading_system called'* ]]
	grep -q -- '-y -d dist-upgrade' "$STUB_DIR/apt-get.calls"
}

@test "display_previous_upgrade_notice warns when resuming a failed upgrade" {
	resuming_failed_upgrade=1

	run display_previous_upgrade_notice

	[[ "$output" == *'the previous upgrade did not complete'* ]]
}

@test "display_previous_upgrade_notice prints nothing on a normal upgrade" {
	resuming_failed_upgrade=0

	run display_previous_upgrade_notice

	[ -z "$output" ]
}

@test "display_asterisk_notice moves custom modules to /tmp and warns" {
	stub dpkg-query 0 '8:19.2.0'
	stub dpkg 0
	stub wazo-asterisk-custom-modules 0 'codec_g729a.so'
	stub mv 0

	run display_asterisk_notice

	[ "$status" -eq 0 ]
	[[ "$output" == *'Asterisk will be upgraded from version 19 to 20'* ]]
	[[ "$output" == *'WARNING: custom Asterisk modules detected'* ]]
	grep -q 'mv /usr/lib/asterisk/modules/codec_g729a.so /tmp' "$STUB_DIR/mv.calls"
}

@test "display_asterisk_notice does not warn without custom modules" {
	stub dpkg-query 0 '8:19.2.0'
	stub dpkg 0
	stub wazo-asterisk-custom-modules 0

	run display_asterisk_notice

	[ "$status" -eq 0 ]
	[[ "$output" == *'Asterisk will be upgraded'* ]]
	[[ "$output" != *'custom Asterisk modules detected'* ]]
}

@test "display_asterisk_notice prints nothing when asterisk is already newer" {
	stub dpkg-query 0 '8:22.1.0'
	stub dpkg 1
	stub mv 0

	run display_asterisk_notice

	[ "$status" -eq 0 ]
	[ -z "$output" ]
	[ ! -f "$STUB_DIR/mv.calls" ]
}

@test "upgrade runs every step in order, conffile check before pre-start" {
	stub_upgrade_environment
	make_phase_script pre-start 10-ok.sh

	upgrade

	[ "$(recorded_calls)" = "$(printf '%s\n' \
		'stop_wazo' \
		'execute apt-get install' \
		'execute apt-get install' \
		'execute apt-get install' \
		'execute apt-get install' \
		'execute apt-mark auto' \
		'execute apt-get dist-upgrade' \
		'execute apt-get autoremove' \
		'wazo-check-conffiles' \
		'10-ok.sh' \
		'start_wazo')" ]
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
