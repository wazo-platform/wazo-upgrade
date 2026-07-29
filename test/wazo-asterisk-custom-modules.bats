#!/usr/bin/env bats

load test_helper/common

setup() {
    WORK_DIR="$(mktemp -d "${BATS_TMPDIR:-${TMPDIR:-/tmp}}/wazo-asterisk-modules-XXXXXX")"
    mkdir -p "${WORK_DIR}/modules"

    SCRIPT="${REPO_ROOT}/bin/wazo-asterisk-custom-modules"
    export ASTERISK_MODULES_DIR="${WORK_DIR}/modules"
    export ASTERISK_MD5SUMS_FILE="${WORK_DIR}/asterisk.md5sums"
    : > "$ASTERISK_MD5SUMS_FILE"
}

teardown() {
    rm -rf "$WORK_DIR"
}

# md5sums lines look like: <hash>  usr/lib/asterisk/modules/<name>.so
md5sums_line_for_module() {
    printf '0123456789abcdef0123456789abcdef  usr/lib/asterisk/modules/%s\n' "$1"
}

@test "reports nothing when every installed module is standard (dpkg-tracked)" {
    touch "${ASTERISK_MODULES_DIR}/chan_sip.so"
    md5sums_line_for_module chan_sip.so > "$ASTERISK_MD5SUMS_FILE"

    run "$SCRIPT"

    assert_success
    assert_output ''
}

@test "reports nothing when every installed module is one of the always-allowed extras" {
    touch "${ASTERISK_MODULES_DIR}/chan_sccp.so"
    touch "${ASTERISK_MODULES_DIR}/res_amqp.so"

    run "$SCRIPT"

    assert_success
    assert_output ''
}

@test "reports an installed module that is neither dpkg-tracked nor an allowed extra" {
    touch "${ASTERISK_MODULES_DIR}/chan_sip.so"
    touch "${ASTERISK_MODULES_DIR}/codec_g729a.so"
    md5sums_line_for_module chan_sip.so > "$ASTERISK_MD5SUMS_FILE"

    run "$SCRIPT"

    assert_success
    assert_output 'codec_g729a.so'
}

@test "does not report a standard module that dpkg tracks but is not actually installed" {
    md5sums_line_for_module chan_sip.so > "$ASTERISK_MD5SUMS_FILE"
    # modules dir is empty: chan_sip.so listed by dpkg but not installed on disk

    run "$SCRIPT"

    assert_success
    assert_output ''
}

@test "ignores non-.so files in the modules directory" {
    touch "${ASTERISK_MODULES_DIR}/README.txt"

    run "$SCRIPT"

    assert_success
    assert_output ''
}
