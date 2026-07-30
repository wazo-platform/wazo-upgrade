# Copyright 2026 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

# Resolved from this file's own location: BATS_TEST_DIRNAME varies with the
# test file's nesting (e.g. tests/pre-start.d/*.bats)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source_real_wazo_upgrade() {
	source "$REPO_ROOT/bin/real-wazo-upgrade"
	lib_directory="$BATS_TEST_TMPDIR/lib"
	upgrade_incomplete_file="$BATS_TEST_TMPDIR/upgrade-incomplete"
	calls_file="$BATS_TEST_TMPDIR/calls"
}

# Creates an executable script in the fake phase directory that records its
# own name in $calls_file, then exits with the given status (default 0)
make_phase_script() {
	local phase=$1 name=$2 exit_status=${3:-0}
	local dir="$lib_directory/$phase.d"
	mkdir -p "$dir"
	cat > "$dir/$name" <<-EOF
	#!/bin/bash
	echo "$name" >> "$calls_file"
	exit $exit_status
	EOF
	chmod +x "$dir/$name"
}

recorded_calls() {
	cat "$calls_file" 2>/dev/null
}

# Exported: hand-written stub scripts run as child processes and need it too.
# Call again (or re-prepend PATH) after sourcing a script that resets PATH.
stub_path_setup() {
	export STUB_DIR="$BATS_TEST_TMPDIR/stubs"
	mkdir -p "$STUB_DIR"
	PATH="$STUB_DIR:$PATH"
}

# stub <command> <exit_status> [output]
# The stub records each invocation (command + args) in $STUB_DIR/<command>.calls
stub() {
	local name=$1 exit_status=$2 output=${3:-}
	local stub_file="$STUB_DIR/$name"
	cat > "$stub_file" <<-EOF
	#!/bin/bash
	echo "\$0 \$*" >> "$STUB_DIR/$name.calls"
	EOF
	if [ -n "$output" ]; then
		printf 'cat <<'\''STUB_OUTPUT_EOF'\''\n%s\nSTUB_OUTPUT_EOF\n' "$output" >> "$stub_file"
	fi
	echo "exit $exit_status" >> "$stub_file"
	chmod +x "$stub_file"
}

stub_call_count() {
	local calls_file="$STUB_DIR/$1.calls"
	if [ -f "$calls_file" ]; then
		wc -l < "$calls_file"
	else
		echo 0
	fi
}

# Replaces every step of upgrade() that touches the system; tests re-stub
# the pieces they exercise
stub_upgrade_environment() {
	execute() { :; }
	stop_wazo() { echo stop_wazo >> "$calls_file"; }
	start_wazo() { echo start_wazo >> "$calls_file"; }
	wazo-check-conffiles() { :; }
	wazo_version_installed() { echo '26.09'; }
	wazo_version_candidate() { echo '26.10'; }
}
