#!/usr/bin/env bats
# Copyright 2026 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

load ../test_helper

setup() {
	stub_path_setup
	SCRIPT="$REPO_ROOT/pre-start.d/20-wazo-update-keys.sh"
}

# stub_systemctl <restart_status> <stop_status>: systemctl responds
# differently to "restart wazo-auth" vs "stop wazo-auth" so tests can make
# the trap's cleanup succeed or fail independently of the main command
stub_systemctl() {
	cat > "$STUB_DIR/systemctl" <<-EOF
	#!/bin/bash
	echo "systemctl \$*" >> "$STUB_DIR/systemctl.calls"
	case "\$1 \$2" in
	    "restart wazo-auth") exit $1;;
	    "stop wazo-auth") exit $2;;
	esac
	exit 0
	EOF
	chmod +x "$STUB_DIR/systemctl"
}

@test "restarts wazo-auth, runs both wazo-auth-keys commands, stops wazo-auth on exit" {
	stub_systemctl 0 0
	stub wazo-auth-keys 0

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	# order matters: restart first, stop last (EXIT trap)
	[ "$(head -n 1 "$STUB_DIR/systemctl.calls")" = 'systemctl restart wazo-auth' ]
	[ "$(tail -n 1 "$STUB_DIR/systemctl.calls")" = 'systemctl stop wazo-auth' ]
	grep -q 'service update' "$STUB_DIR/wazo-auth-keys.calls"
	grep -q 'service clean --users' "$STUB_DIR/wazo-auth-keys.calls"
}

@test "aborts before 'service clean' when 'service update' fails, but still stops wazo-auth" {
	stub_systemctl 0 0
	# STUB_DIR is exported: the quoted heredoc resolves it when the stub runs
	cat > "$STUB_DIR/wazo-auth-keys" <<-'EOF'
	#!/bin/bash
	echo "$0 $*" >> "$STUB_DIR/wazo-auth-keys.calls"
	if [ "$1 $2" = 'service update' ]; then
	    exit 1
	fi
	exit 0
	EOF
	chmod +x "$STUB_DIR/wazo-auth-keys"

	run "$SCRIPT"

	[ "$status" -ne 0 ]
	grep -q 'stop wazo-auth' "$STUB_DIR/systemctl.calls"
	run grep -q 'service clean --users' "$STUB_DIR/wazo-auth-keys.calls"
	[ "$status" -ne 0 ]
}

@test "preserves the original failure's exit status even if the trap's stop also fails" {
	stub_systemctl 0 1
	stub wazo-auth-keys 3

	run "$SCRIPT"

	[ "$status" -eq 3 ]
}
