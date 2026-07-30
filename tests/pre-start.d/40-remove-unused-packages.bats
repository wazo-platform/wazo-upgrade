#!/usr/bin/env bats
# Copyright 2026 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

load ../test_helper

setup() {
	stub_path_setup
	SCRIPT="$REPO_ROOT/pre-start.d/40-remove-unused-packages.sh"
	stub_dpkg_query
}

# dpkg_status <package> <status-string> records the response the dpkg-query
# stub gives for that package. Packages with no recorded status make
# dpkg-query fail (exit 1, no output), like a package dpkg has never heard of
dpkg_status() {
	echo "$2" > "$STUB_DIR/dpkg-status-$1"
}

stub_dpkg_query() {
	# STUB_DIR is exported: the quoted heredoc resolves it when the stub runs
	cat > "$STUB_DIR/dpkg-query" <<-'EOF'
	#!/bin/bash
	package="${@: -1}"
	echo "dpkg-query $*" >> "$STUB_DIR/dpkg-query.calls"
	status_file="$STUB_DIR/dpkg-status-$package"
	if [ -f "$status_file" ]; then
	    cat "$status_file"
	    exit 0
	fi
	exit 1
	EOF
	chmod +x "$STUB_DIR/dpkg-query"
}

@test "purges nothing when dpkg has never heard of the renamed/removed packages" {
	stub apt-get 0
	stub systemctl 0

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ ! -f "$STUB_DIR/apt-get.calls" ]
}

@test "purges a renamed package that is still installed under its old name" {
	dpkg_status xivo-certs 'install ok installed'
	dpkg_status xivo-sync 'unknown ok not-installed'
	dpkg_status xivo-swagger-doc 'unknown ok not-installed'
	stub apt-get 0
	stub systemctl 0

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	grep -q 'purge -y xivo-certs' "$STUB_DIR/apt-get.calls"
	run grep -q 'purge -y xivo-sync' "$STUB_DIR/apt-get.calls"
	[ "$status" -ne 0 ]
}

@test "a failed purge is reported as a warning but does not abort the script" {
	dpkg_status xivo-certs 'install ok installed'
	dpkg_status xivo-sync 'install ok installed'
	dpkg_status xivo-swagger-doc 'unknown ok not-installed'
	stub apt-get 1
	stub systemctl 0

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[[ "$output" == *'WARNING: could not purge xivo-certs'* ]]
	[[ "$output" == *'WARNING: could not purge xivo-sync'* ]]
	[ "$(stub_call_count apt-get)" -eq 2 ]
}

@test "does not touch postgresql-13 when wazo-dbms is not installed" {
	dpkg_status wazo-dbms 'unknown ok not-installed'
	stub apt-get 0
	stub systemctl 0

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ ! -f "$STUB_DIR/systemctl.calls" ]
}

@test "purges postgresql-13 and restarts postgresql when wazo-dbms is installed" {
	dpkg_status wazo-dbms 'install ok installed'
	dpkg_status postgresql-13 'install ok installed'
	stub apt-get 0
	stub systemctl 0

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	grep -q 'purge -y postgresql-13 postgresql-client-13 postgresql-contrib-13' "$STUB_DIR/apt-get.calls"
	grep -q 'restart postgresql.service' "$STUB_DIR/systemctl.calls"
}

@test "restarts postgresql even when the postgresql-13 purge fails" {
	dpkg_status wazo-dbms 'install ok installed'
	dpkg_status postgresql-13 'install ok installed'
	stub apt-get 1
	stub systemctl 0

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[[ "$output" == *'WARNING: could not purge all postgresql-13 packages'* ]]
	grep -q 'restart postgresql.service' "$STUB_DIR/systemctl.calls"
}

@test "does not restart postgresql when postgresql-13 is already fully purged" {
	dpkg_status wazo-dbms 'install ok installed'
	dpkg_status postgresql-13 'unknown ok not-installed'
	stub apt-get 0
	stub systemctl 0

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ ! -f "$STUB_DIR/systemctl.calls" ]
}
