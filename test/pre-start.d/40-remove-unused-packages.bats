#!/usr/bin/env bats

load ../test_helper/common

setup() {
    stub_path_setup
    SCRIPT="${REPO_ROOT}/pre-start.d/40-remove-unused-packages.sh"
}

teardown() {
    stub_path_teardown
}

# dpkg_status <package> <status-string> records the `dpkg-query -W -f '${Status}' <package>`
# response the stub should give. Packages with no recorded status make
# dpkg-query "fail" (exit 1, no output), like a package dpkg has never heard of.
dpkg_status() {
    echo "$2" > "${STUB_DIR}/dpkg-status-$1"
}

stub_dpkg_query() {
    cat > "${STUB_DIR}/dpkg-query" <<'EOF'
#!/bin/bash
package="${@: -1}"
echo "dpkg-query $*" >> "${STUB_DIR_MARKER}/dpkg-query.calls"
status_file="${STUB_DIR_MARKER}/dpkg-status-${package}"
if [ -f "$status_file" ]; then
    cat "$status_file"
    exit 0
fi
exit 1
EOF
    # Substitute STUB_DIR_MARKER with the real path (avoids quoting headaches
    # from embedding $STUB_DIR directly in the heredoc above).
    sed -i "s#\${STUB_DIR_MARKER}#${STUB_DIR}#g" "${STUB_DIR}/dpkg-query"
    chmod +x "${STUB_DIR}/dpkg-query"
}

@test "purges none of the renamed/removed packages when dpkg has never heard of them" {
    stub_dpkg_query
    stub apt-get 0
    stub systemctl 0

    run "$SCRIPT"

    assert_success
    [ ! -f "${STUB_DIR}/apt-get.calls" ]
}

@test "purges a renamed package that is still installed under its old name" {
    stub_dpkg_query
    dpkg_status xivo-certs 'install ok installed'
    dpkg_status xivo-sync 'unknown ok not-installed'
    dpkg_status xivo-swagger-doc 'unknown ok not-installed'
    stub apt-get 0
    stub systemctl 0

    run "$SCRIPT"

    assert_success
    grep -q 'purge -y xivo-certs' "${STUB_DIR}/apt-get.calls"
    ! grep -q 'purge -y xivo-sync' "${STUB_DIR}/apt-get.calls"
}

@test "a failed purge is reported as a warning but does not abort the script" {
    stub_dpkg_query
    dpkg_status xivo-certs 'install ok installed'
    dpkg_status xivo-sync 'install ok installed'
    dpkg_status xivo-swagger-doc 'unknown ok not-installed'
    stub apt-get 1
    stub systemctl 0

    run "$SCRIPT"

    assert_success
    assert_output --partial 'WARNING: could not purge xivo-certs'
    assert_output --partial 'WARNING: could not purge xivo-sync'
    [ "$(stub_call_count apt-get)" -eq 2 ]
}

@test "leaves postgresql-13 alone and does not restart postgresql when wazo-dbms is not installed" {
    stub_dpkg_query
    dpkg_status wazo-dbms 'unknown ok not-installed'
    dpkg_status xivo-certs 'unknown ok not-installed'
    dpkg_status xivo-sync 'unknown ok not-installed'
    dpkg_status xivo-swagger-doc 'unknown ok not-installed'
    stub apt-get 0
    stub systemctl 0

    run "$SCRIPT"

    assert_success
    [ ! -f "${STUB_DIR}/systemctl.calls" ]
}

@test "purges postgresql-13 and restarts postgresql when wazo-dbms is installed and postgresql-13 is purgeable" {
    stub_dpkg_query
    dpkg_status wazo-dbms 'install ok installed'
    dpkg_status postgresql-13 'install ok installed'
    dpkg_status xivo-certs 'unknown ok not-installed'
    dpkg_status xivo-sync 'unknown ok not-installed'
    dpkg_status xivo-swagger-doc 'unknown ok not-installed'
    stub apt-get 0
    stub systemctl 0

    run "$SCRIPT"

    assert_success
    grep -q 'purge -y postgresql-13 postgresql-client-13 postgresql-contrib-13' "${STUB_DIR}/apt-get.calls"
    grep -q 'restart postgresql.service' "${STUB_DIR}/systemctl.calls"
}

@test "restarts postgresql even when the postgresql-13 purge fails (best-effort, not gating the restart)" {
    stub_dpkg_query
    dpkg_status wazo-dbms 'install ok installed'
    dpkg_status postgresql-13 'install ok installed'
    dpkg_status xivo-certs 'unknown ok not-installed'
    dpkg_status xivo-sync 'unknown ok not-installed'
    dpkg_status xivo-swagger-doc 'unknown ok not-installed'
    stub apt-get 1
    stub systemctl 0

    run "$SCRIPT"

    assert_success
    assert_output --partial 'WARNING: could not purge all postgresql-13 packages'
    grep -q 'restart postgresql.service' "${STUB_DIR}/systemctl.calls"
}

@test "does not restart postgresql when wazo-dbms is installed but postgresql-13 is already fully purged" {
    stub_dpkg_query
    dpkg_status wazo-dbms 'install ok installed'
    dpkg_status postgresql-13 'unknown ok not-installed'
    dpkg_status xivo-certs 'unknown ok not-installed'
    dpkg_status xivo-sync 'unknown ok not-installed'
    dpkg_status xivo-swagger-doc 'unknown ok not-installed'
    stub apt-get 0
    stub systemctl 0

    run "$SCRIPT"

    assert_success
    [ ! -f "${STUB_DIR}/systemctl.calls" ]
}
