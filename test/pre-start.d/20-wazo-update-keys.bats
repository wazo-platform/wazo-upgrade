#!/usr/bin/env bats

load ../test_helper/common

setup() {
    stub_path_setup
    SCRIPT="${REPO_ROOT}/pre-start.d/20-wazo-update-keys.sh"
}

teardown() {
    stub_path_teardown
}

# stub_systemctl <restart_status> <stop_status>: systemctl responds
# differently to "restart wazo-auth" vs "stop wazo-auth" so tests can make
# the trap's cleanup succeed or fail independently of the main command.
stub_systemctl() {
    cat > "${STUB_DIR}/systemctl" <<EOF
#!/bin/bash
echo "systemctl \$*" >> "${STUB_DIR}/systemctl.calls"
case "\$1 \$2" in
    "restart wazo-auth") exit ${1};;
    "stop wazo-auth") exit ${2};;
esac
exit 0
EOF
    chmod +x "${STUB_DIR}/systemctl"
}

@test "runs restart then both wazo-auth-keys commands, then stops wazo-auth on exit" {
    stub_systemctl 0 0
    stub wazo-auth-keys 0

    run "$SCRIPT"

    assert_success
    # order matters: restart before the key commands, stop happens last (EXIT trap)
    grep -n 'restart wazo-auth' "${STUB_DIR}/systemctl.calls"
    grep -n 'stop wazo-auth' "${STUB_DIR}/systemctl.calls"
    grep -q 'service update' "${STUB_DIR}/wazo-auth-keys.calls"
    grep -q 'service clean --users' "${STUB_DIR}/wazo-auth-keys.calls"
}

@test "aborts before 'service clean' when 'service update' fails, but still stops wazo-auth" {
    stub_systemctl 0 0
    cat > "${STUB_DIR}/wazo-auth-keys" <<'EOF'
#!/bin/bash
echo "$0 $*" >> "${STUB_DIR}/wazo-auth-keys.calls"
if [ "$1 $2" == "service update" ]; then
    exit 1
fi
exit 0
EOF
    sed -i "s#\${STUB_DIR}#${STUB_DIR}#g" "${STUB_DIR}/wazo-auth-keys"
    chmod +x "${STUB_DIR}/wazo-auth-keys"

    run "$SCRIPT"

    assert_failure
    grep -q 'stop wazo-auth' "${STUB_DIR}/systemctl.calls"
    ! grep -q 'service clean --users' "${STUB_DIR}/wazo-auth-keys.calls"
}

@test "preserves the original failure's exit status even if the EXIT trap's stop also fails" {
    stub_systemctl 0 1  # restart succeeds, stop (trap) fails
    cat > "${STUB_DIR}/wazo-auth-keys" <<'EOF'
#!/bin/bash
echo "$0 $*" >> "${STUB_DIR}/wazo-auth-keys.calls"
exit 3
EOF
    chmod +x "${STUB_DIR}/wazo-auth-keys"

    run "$SCRIPT"

    assert_failure 3
}
