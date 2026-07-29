#!/usr/bin/env bats

load test_helper/common

setup() {
    stub_path_setup
    SCRIPT="${REPO_ROOT}/bin/apt-warning"
}

teardown() {
    stub_path_teardown
}

@test "apt-warning: passes through non-upgrade actions without prompting" {
    stub apt 0

    run bash -c "printf '' | '${SCRIPT}' install foo"

    assert_success
    refute_output --partial 'WARNING'
    [ "$(stub_call_count apt)" -eq 1 ]
    grep -q 'install foo' "${STUB_DIR}/apt.calls"
}

@test "apt-warning: warns and proceeds on 'y' for upgrade" {
    stub apt 0

    run bash -c "printf 'y\n' | '${SCRIPT}' upgrade"

    assert_success
    assert_output --partial 'WARNING: This command is not supported'
    [ "$(stub_call_count apt)" -eq 1 ]
}

@test "apt-warning: warns and proceeds on 'Y' for dist-upgrade" {
    stub apt 0

    run bash -c "printf 'Y\n' | '${SCRIPT}' dist-upgrade"

    assert_success
    [ "$(stub_call_count apt)" -eq 1 ]
}

@test "apt-warning: warns and proceeds on 'y' for full-upgrade" {
    stub apt 0

    run bash -c "printf 'y\n' | '${SCRIPT}' full-upgrade"

    assert_success
    [ "$(stub_call_count apt)" -eq 1 ]
}

@test "apt-warning: aborts on explicit 'n' for upgrade" {
    stub apt 0

    run bash -c "printf 'n\n' | '${SCRIPT}' upgrade"

    assert_failure 1
    [ ! -f "${STUB_DIR}/apt.calls" ]
}

@test "apt-warning: defaults to 'N' (abort) when answer is empty" {
    stub apt 0

    run bash -c "printf '\n' | '${SCRIPT}' upgrade"

    assert_failure 1
    [ ! -f "${STUB_DIR}/apt.calls" ]
}

@test "apt-warning: forwards apt's exit status for non-warning actions" {
    stub apt 42

    run bash -c "printf '' | '${SCRIPT}' list foo"

    assert_failure 42
}
