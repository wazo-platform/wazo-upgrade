#!/usr/bin/env bats

load test_helper/common

setup() {
    WORK_DIR="$(mktemp -d "${BATS_TMPDIR:-${TMPDIR:-/tmp}}/wazo-check-conffiles-XXXXXX")"
    mkdir -p "${WORK_DIR}/etc/xivo"

    XIVO_CONFIG_CONFFILES_LIST="${WORK_DIR}/conffiles_list"
    SYSTEMD_SYSTEM_CONF="${WORK_DIR}/system.conf"
    : > "$XIVO_CONFIG_CONFFILES_LIST"
    : > "$SYSTEMD_SYSTEM_CONF"

    source "${REPO_ROOT}/bin/wazo-check-conffiles"
}

teardown() {
    rm -rf "$WORK_DIR"
}

@test "list_modified_conffiles: reports nothing when no .dpkg-old backups exist" {
    echo "${WORK_DIR}/etc/xivo/ring.conf" > "$XIVO_CONFIG_CONFFILES_LIST"

    run list_modified_conffiles

    assert_success
    assert_output ''
}

@test "list_modified_conffiles: reports a conffile that dpkg overwrote (has a .dpkg-old backup)" {
    echo "${WORK_DIR}/etc/xivo/ring.conf" > "$XIVO_CONFIG_CONFFILES_LIST"
    touch "${WORK_DIR}/etc/xivo/ring.conf.dpkg-old"

    run list_modified_conffiles

    assert_success
    assert_output "${WORK_DIR}/etc/xivo/ring.conf"
}

@test "list_modified_conffiles: also checks the systemd system.conf, not just dpkg-tracked conffiles" {
    touch "${SYSTEMD_SYSTEM_CONF}.dpkg-old"

    run list_modified_conffiles

    assert_success
    assert_output "$SYSTEMD_SYSTEM_CONF"
}

@test "list_modified_conffiles: an ignored .dpkg-old (matching IGNORE_LIST by md5sum) is removed and not reported" {
    echo "${WORK_DIR}/etc/xivo/ring.conf" > "$XIVO_CONFIG_CONFFILES_LIST"
    echo -n 'stale backup' > "${WORK_DIR}/etc/xivo/ring.conf.dpkg-old"
    IGNORE_LIST="$(md5sum "${WORK_DIR}/etc/xivo/ring.conf.dpkg-old")"

    run list_modified_conffiles

    assert_success
    assert_output ''
    [ ! -f "${WORK_DIR}/etc/xivo/ring.conf.dpkg-old" ]
}

@test "is_conffile_old_ignored: true when the file's md5sum is in IGNORE_LIST" {
    echo -n 'stale backup' > "${WORK_DIR}/old.dpkg-old"
    IGNORE_LIST="$(md5sum "${WORK_DIR}/old.dpkg-old")"

    run is_conffile_old_ignored "${WORK_DIR}/old.dpkg-old"

    assert_success
}

@test "is_conffile_old_ignored: false when IGNORE_LIST is empty" {
    echo -n 'stale backup' > "${WORK_DIR}/old.dpkg-old"

    run is_conffile_old_ignored "${WORK_DIR}/old.dpkg-old"

    assert_failure
}

@test "main: prints a warning naming the modified files when any were overwritten" {
    echo "${WORK_DIR}/etc/xivo/ring.conf" > "$XIVO_CONFIG_CONFFILES_LIST"
    touch "${WORK_DIR}/etc/xivo/ring.conf.dpkg-old"

    run main

    assert_success
    assert_output --partial 'WARNING: The following configuration files were overwritten'
    assert_output --partial "${WORK_DIR}/etc/xivo/ring.conf"
    assert_output --partial 'vimdiff FILENAME FILENAME.dpkg-old'
}

@test "main: prints nothing when no conffiles were overwritten" {
    echo "${WORK_DIR}/etc/xivo/ring.conf" > "$XIVO_CONFIG_CONFFILES_LIST"

    run main

    assert_success
    assert_output ''
}
