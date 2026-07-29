#!/usr/bin/env bats

load test_helper/common

setup() {
    stub_path_setup
    SCRIPT="${REPO_ROOT}/bin/apt-get-warning"
}

teardown() {
    stub_path_teardown
}

@test "apt-get-warning: passes through non-upgrade actions without prompting" {
    stub apt-get 0

    run bash -c "printf '' | '${SCRIPT}' install foo"

    assert_success
    refute_output --partial 'WARNING'
    [ "$(stub_call_count apt-get)" -eq 1 ]
    grep -q 'install foo' "${STUB_DIR}/apt-get.calls"
}

@test "apt-get-warning: warns and proceeds on 'y' for upgrade" {
    stub apt-get 0

    run bash -c "printf 'y\n' | '${SCRIPT}' upgrade"

    assert_success
    assert_output --partial 'WARNING: This command is not supported'
    [ "$(stub_call_count apt-get)" -eq 1 ]
}

@test "apt-get-warning: warns and proceeds on 'Y' for dist-upgrade" {
    stub apt-get 0

    run bash -c "printf 'Y\n' | '${SCRIPT}' dist-upgrade"

    assert_success
    [ "$(stub_call_count apt-get)" -eq 1 ]
}

@test "apt-get-warning: does not treat full-upgrade as a warning action" {
    # unlike apt-warning, apt-get has no 'full-upgrade' alias
    stub apt-get 0

    run bash -c "printf '' | '${SCRIPT}' full-upgrade"

    assert_success
    refute_output --partial 'WARNING'
    [ "$(stub_call_count apt-get)" -eq 1 ]
}

@test "apt-get-warning: aborts on explicit 'n' for upgrade" {
    stub apt-get 0

    run bash -c "printf 'n\n' | '${SCRIPT}' upgrade"

    assert_failure 1
    [ ! -f "${STUB_DIR}/apt-get.calls" ]
}

@test "apt-get-warning: defaults to 'N' (abort) when answer is empty" {
    stub apt-get 0

    run bash -c "printf '\n' | '${SCRIPT}' upgrade"

    assert_failure 1
    [ ! -f "${STUB_DIR}/apt-get.calls" ]
}

@test "apt-get-warning: forwards apt-get's exit status for non-warning actions" {
    stub apt-get 42

    run bash -c "printf '' | '${SCRIPT}' list foo"

    assert_failure 42
}
