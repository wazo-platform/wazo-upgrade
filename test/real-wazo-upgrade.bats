#!/usr/bin/env bats

load test_helper/common

setup() {
    stub_path_setup
    LIB_DIR="$(mktemp -d "${BATS_TMPDIR:-${TMPDIR:-/tmp}}/wazo-upgrade-libdir-XXXXXX")"
    mkdir -p "$LIB_DIR/pre-stop.d" "$LIB_DIR/post-stop.d" "$LIB_DIR/pre-start.d" "$LIB_DIR/post-start.d"

    # Load the script's functions without triggering its main-line logic
    # (getopts, db-migration check, wizard check, upgrade).
    lib_directory="$LIB_DIR"
    upgrade_incomplete_file="${BATS_TMPDIR:-${TMPDIR:-/tmp}}/upgrade-incomplete-nonexistent"
    source "${REPO_ROOT}/bin/real-wazo-upgrade"
    # The script hard-resets PATH to trusted system dirs only (deliberately,
    # to ignore the caller's PATH); re-prepend our stub dir now that sourcing
    # is done so the functions under test can still reach our stubs.
    PATH="${STUB_DIR}:${PATH}"
}

teardown() {
    stub_path_teardown
    rm -rf "$LIB_DIR"
}

write_script() {
    local dir=$1 name=$2 exit_status=$3
    cat > "${dir}/${name}" <<EOF
#!/bin/bash
echo "ran ${name}" >> "${LIB_DIR}/executed.log"
exit ${exit_status}
EOF
    chmod +x "${dir}/${name}"
}

@test "run_upgrade_scripts: runs every script in the state directory when all succeed" {
    write_script "$LIB_DIR/pre-start.d" 10-first 0
    write_script "$LIB_DIR/pre-start.d" 20-second 0

    run_upgrade_scripts pre-start
    status=$?

    [ "$status" -eq 0 ]
    [ -z "$failed_script" ]
    [ "$(cat "$LIB_DIR/executed.log")" == "$(printf 'ran 10-first\nran 20-second')" ]
}

@test "run_upgrade_scripts: stops at the first failing script and does not run later ones" {
    write_script "$LIB_DIR/pre-start.d" 10-first 0
    write_script "$LIB_DIR/pre-start.d" 20-failing 1
    write_script "$LIB_DIR/pre-start.d" 30-never-runs 0

    # Not using `run` here: it forks a subshell via command substitution, so
    # $failed_script (set inside run_upgrade_scripts) wouldn't survive back
    # to this shell. The && / || form avoids tripping bats' `set -e`.
    run_upgrade_scripts pre-start && status=0 || status=$?

    [ "$status" -ne 0 ]
    [[ "$failed_script" == *"20-failing" ]]
    [ "$(cat "$LIB_DIR/executed.log")" == "$(printf 'ran 10-first\nran 20-failing')" ]
}

@test "run_upgrade_scripts: succeeds when the state directory has no scripts" {
    run_upgrade_scripts post-stop
    status=$?

    [ "$status" -eq 0 ]
    [ -z "$failed_script" ]
}

@test "pre_stop: aborts with fatal_error on script failure, without restarting wazo" {
    write_script "$LIB_DIR/pre-stop.d" 10-failing 1
    stub wazo-service 0

    run pre_stop

    assert_failure
    assert_output --partial 'Failed to execute'
    assert_output --partial '10-failing'
    [ ! -f "${STUB_DIR}/wazo-service.calls" ]
}

@test "post_stop: restarts wazo before the fatal_error on script failure" {
    write_script "$LIB_DIR/post-stop.d" 10-failing 1
    stub wazo-service 0

    run post_stop

    assert_failure
    assert_output --partial 'Failed to execute'
    # start_wazo calls: enable, then restart
    grep -q 'wazo-service enable' "${STUB_DIR}/wazo-service.calls"
    grep -q 'wazo-service restart' "${STUB_DIR}/wazo-service.calls"
}

@test "pre_start: restarts wazo before the fatal_error on script failure" {
    write_script "$LIB_DIR/pre-start.d" 10-failing 1
    stub wazo-service 0

    run pre_start

    assert_failure
    assert_output --partial 'The system is only partially upgraded'
    grep -q 'wazo-service enable' "${STUB_DIR}/wazo-service.calls"
    grep -q 'wazo-service restart' "${STUB_DIR}/wazo-service.calls"
}

@test "post_start: reports failed scripts as a warning without aborting" {
    write_script "$LIB_DIR/post-start.d" 10-failing 1
    write_script "$LIB_DIR/post-start.d" 20-ok 0

    run post_start

    assert_success
    assert_output --partial 'WARNING'
    # exactly the failing script is named in the summary line; the
    # successful one is only mentioned in the per-script "Executing..." trace
    assert_line --partial 'Failed to execute the following scripts: '"${LIB_DIR}"'/post-start.d/10-failing'
}

@test "post_start: prints nothing when every script succeeds" {
    write_script "$LIB_DIR/post-start.d" 10-ok 0

    run post_start

    assert_success
    refute_output --partial 'WARNING'
}

@test "main() actually runs when the script is executed directly (not just sourced)" {
    # every other test in this file sources the script, which only proves
    # main() is correctly suppressed on source; this proves the other half
    # of the guard, that direct execution still reaches main().
    run "${REPO_ROOT}/bin/real-wazo-upgrade" -h

    assert_success
    assert_output --partial 'usage: wazo-upgrade'
}
