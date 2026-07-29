#!/usr/bin/env bats

load ../test_helper/common

setup() {
    WORK_DIR="$(mktemp -d "${BATS_TMPDIR:-${TMPDIR:-/tmp}}/wazo-provd-configs-XXXXXX")"
    export CONFIGS_DIR="${WORK_DIR}/configs"
    mkdir -p "$CONFIGS_DIR"
    SCRIPT="${REPO_ROOT}/pre-start.d/30-fix-provd-deletable-configs.sh"
}

teardown() {
    rm -rf "$WORK_DIR"
}

@test "restores deletable=false on a wizard config that was flipped to true" {
    echo '{"id": "base", "deletable": true}' > "${CONFIGS_DIR}/base"

    run "$SCRIPT"

    assert_success
    assert_output --partial "Restoring deletable=false on ${CONFIGS_DIR}/base"
    run jq -r '.deletable' "${CONFIGS_DIR}/base"
    assert_output 'false'
}

@test "leaves a wizard config alone when deletable is already false" {
    echo '{"id": "default", "deletable": false}' > "${CONFIGS_DIR}/default"
    before="$(md5sum "${CONFIGS_DIR}/default")"

    run "$SCRIPT"

    assert_success
    refute_output --partial 'Restoring'
    [ "$(md5sum "${CONFIGS_DIR}/default")" == "$before" ]
}

@test "preserves the rest of the config's JSON content when fixing deletable" {
    echo '{"id": "autoprov", "deletable": true, "label": "Autoprovisioning"}' > "${CONFIGS_DIR}/autoprov"

    run "$SCRIPT"

    assert_success
    run jq -c -S . "${CONFIGS_DIR}/autoprov"
    assert_output '{"deletable":false,"id":"autoprov","label":"Autoprovisioning"}'
}

@test "ignores configs that are not one of the four wizard configs" {
    echo '{"id": "custom", "deletable": true}' > "${CONFIGS_DIR}/custom"

    run "$SCRIPT"

    assert_success
    run jq -r '.deletable' "${CONFIGS_DIR}/custom"
    assert_output 'true'
}

@test "does nothing (and does not fail) when a wizard config file does not exist" {
    # none of base/default/defaultconfigdevice/autoprov are present

    run "$SCRIPT"

    assert_success
    assert_output ''
}

@test "does nothing (and does not fail) when the configs directory itself does not exist" {
    export CONFIGS_DIR="${WORK_DIR}/does-not-exist"

    run "$SCRIPT"

    assert_success
    assert_output ''
}

@test "does not leave a temp file behind after fixing a config" {
    echo '{"id": "base", "deletable": true}' > "${CONFIGS_DIR}/base"

    run "$SCRIPT"

    assert_success
    run bash -c "ls -1 '${CONFIGS_DIR}' | grep -c '^\.'"
    assert_output '0'
}
