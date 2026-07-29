#!/usr/bin/env bats

load ../test_helper/common

setup() {
    WORK_DIR="$(mktemp -d "${BATS_TMPDIR:-${TMPDIR:-/tmp}}/wazo-thread-pool-XXXXXX")"
    export ETC_DIR="${WORK_DIR}/etc"
    export SENTINEL="${WORK_DIR}/var/lib/wazo-upgrade/rename-rest-api-max-threads"
    mkdir -p "$ETC_DIR" "$(dirname "$SENTINEL")"
    SCRIPT="${REPO_ROOT}/pre-start.d/50-preserve-fixed-thread-pool.sh"
}

teardown() {
    rm -rf "$WORK_DIR"
}

write_conf() {
    local service=$1 name=$2 content=$3
    mkdir -p "${ETC_DIR}/${service}/conf.d"
    printf '%s\n' "$content" > "${ETC_DIR}/${service}/conf.d/${name}.yml"
}

@test "renames a custom max_threads to min_threads and creates the sentinel" {
    write_conf wazo-confd 10-custom $'rest_api:\n  max_threads: 42'

    run "$SCRIPT"

    assert_success
    assert_output --partial 'Renaming max_threads to min_threads'
    run cat "${ETC_DIR}/wazo-confd/conf.d/10-custom.yml"
    assert_output $'rest_api:\n  min_threads: 42'
    [ -f "$SENTINEL" ]
}

@test "leaves configs alone that do not set max_threads" {
    write_conf wazo-confd 10-custom $'rest_api:\n  debug: true'

    run "$SCRIPT"

    assert_success
    refute_output --partial 'Renaming'
    run cat "${ETC_DIR}/wazo-confd/conf.d/10-custom.yml"
    assert_output $'rest_api:\n  debug: true'
}

@test "processes every service directory that has conf.d files" {
    write_conf wazo-confd 10-custom $'rest_api:\n  max_threads: 5'
    write_conf wazo-calld 10-custom $'rest_api:\n  max_threads: 8'

    run "$SCRIPT"

    assert_success
    run cat "${ETC_DIR}/wazo-confd/conf.d/10-custom.yml"
    assert_output --partial 'min_threads: 5'
    run cat "${ETC_DIR}/wazo-calld/conf.d/10-custom.yml"
    assert_output --partial 'min_threads: 8'
}

@test "does nothing (and does not fail) for a service with no conf.d directory" {
    # ETC_DIR exists but no service subdirectories at all

    run "$SCRIPT"

    assert_success
    refute_output --partial 'Renaming'
    [ -f "$SENTINEL" ]
}

@test "is a no-op on a system already migrated: sentinel present short-circuits everything" {
    write_conf wazo-confd 10-custom $'rest_api:\n  max_threads: 42'
    touch "$SENTINEL"
    before="$(md5sum "${ETC_DIR}/wazo-confd/conf.d/10-custom.yml")"

    run "$SCRIPT"

    assert_success
    assert_output ''
    [ "$(md5sum "${ETC_DIR}/wazo-confd/conf.d/10-custom.yml")" == "$before" ]
}

@test "does not touch a service whose config never mentions max_threads even when other services do" {
    write_conf wazo-confd 10-custom $'rest_api:\n  max_threads: 42'
    write_conf wazo-auth 10-custom $'rest_api:\n  debug: true'

    run "$SCRIPT"

    assert_success
    run cat "${ETC_DIR}/wazo-auth/conf.d/10-custom.yml"
    assert_output $'rest_api:\n  debug: true'
}
