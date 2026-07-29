#!/usr/bin/env bats

load test_helper/common

setup() {
    stub_path_setup
    WORK_DIR="$(mktemp -d "${BATS_TMPDIR:-${TMPDIR:-/tmp}}/wazo-upgrade-workdir-XXXXXX")"

    LOGFILE="${WORK_DIR}/wazo-upgrade.log"
    REAL_WAZO_UPGRADE="${STUB_DIR}/real-wazo-upgrade"
    source "${REPO_ROOT}/bin/wazo-upgrade"
    # The script hard-resets PATH to trusted system dirs only (deliberately,
    # to ignore the caller's PATH); re-prepend our stub dir now that sourcing
    # is done so the functions under test can still reach our stubs.
    PATH="${STUB_DIR}:${PATH}"
}

teardown() {
    stub_path_teardown
    rm -rf "$WORK_DIR"
}

# apt-cache madison output lines matching '...Packages$' count as available packages
stub_apt_cache_madison_with_package() {
    local package=$1
    cat > "${STUB_DIR}/apt-cache" <<EOF
#!/bin/bash
echo "\$0 \$*" >> "${STUB_DIR}/apt-cache.calls"
if [ "\$1" == "madison" ] && [ "\$2" == "${package}" ]; then
    echo "${package} | 1.0 | http://example/ Packages"
fi
EOF
    chmod +x "${STUB_DIR}/apt-cache"
}

@test "check_package_is_available: true when apt-cache madison lists a Packages entry" {
    stub_apt_cache_madison_with_package bash

    run check_package_is_available bash

    assert_success
}

@test "check_package_is_available: false when apt-cache madison has no match" {
    stub_apt_cache_madison_with_package bash

    run check_package_is_available wazo-upgrade

    assert_failure
}

@test "check_debian_mirror_is_available: fails with a message when bash is unavailable" {
    stub_apt_cache_madison_with_package wazo-upgrade

    run check_debian_mirror_is_available

    assert_failure
    assert_output --partial 'Could not find any Debian repository'
}

@test "check_wazo_mirror_is_available: fails with a message when wazo-upgrade is unavailable" {
    stub_apt_cache_madison_with_package bash

    run check_wazo_mirror_is_available

    assert_failure
    assert_output --partial 'Could not find any Wazo repository'
}

@test "run_upgrade: stops before installing when the debian mirror is unavailable" {
    stub apt-get 0
    stub_apt_cache_madison_with_package wazo-upgrade  # bash missing -> debian mirror check fails
    stub real-wazo-upgrade 0

    run run_upgrade

    assert_failure
    [ ! -f "${STUB_DIR}/real-wazo-upgrade.calls" ]
}

@test "run_upgrade: stops before installing when the wazo mirror is unavailable" {
    stub apt-get 0
    stub_apt_cache_madison_with_package bash  # wazo-upgrade missing -> wazo mirror check fails
    stub real-wazo-upgrade 0

    run run_upgrade

    assert_failure
    [ ! -f "${STUB_DIR}/real-wazo-upgrade.calls" ]
}

@test "run_upgrade: installs wazo-upgrade and delegates to real-wazo-upgrade when both mirrors are available" {
    stub apt-get 0
    stub_apt_cache_madison_with_package bash
    cat > "${STUB_DIR}/apt-cache" <<EOF
#!/bin/bash
echo "\$0 \$*" >> "${STUB_DIR}/apt-cache.calls"
echo "bash | 1.0 | http://example/ Packages"
echo "wazo-upgrade | 1.0 | http://example/ Packages"
EOF
    chmod +x "${STUB_DIR}/apt-cache"
    stub real-wazo-upgrade 0

    run run_upgrade -f

    assert_success
    grep -q 'install.*wazo-upgrade' "${STUB_DIR}/apt-get.calls"
    grep -q -- '-f' "${STUB_DIR}/real-wazo-upgrade.calls"
}

@test "append_log_start: appends a start banner with the current date to the logfile" {
    touch "${WORK_DIR}/log"

    append_log_start "${WORK_DIR}/log"

    run cat "${WORK_DIR}/log"
    assert_output --partial 'wazo-upgrade started at'
}

@test "append_log_end: appends a stop banner with the current date to the logfile" {
    touch "${WORK_DIR}/log"

    append_log_end "${WORK_DIR}/log"

    run cat "${WORK_DIR}/log"
    assert_output --partial 'wazo-upgrade stopped at'
}

@test "log_and_upgrade: reports run_upgrade's exit status (piped through tee), not tee's" {
    # apt-cache lists neither package: check_debian_mirror_is_available fails,
    # so run_upgrade returns 1 deterministically without touching the real apt-cache.
    stub apt-get 0
    stub apt-cache 0

    run log_and_upgrade

    assert_failure 1
    [ -f "$LOGFILE" ]
    grep -q 'wazo-upgrade started at' "$LOGFILE"
    grep -q 'wazo-upgrade stopped at' "$LOGFILE"
    grep -q 'Could not find any Debian repository' "$LOGFILE"
}
