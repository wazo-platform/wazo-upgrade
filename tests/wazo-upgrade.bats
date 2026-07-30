#!/usr/bin/env bats
# Copyright 2026 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

load test_helper

setup() {
	stub_path_setup
	source "$REPO_ROOT/bin/wazo-upgrade"
	# wazo-upgrade hard-resets PATH and assigns LOGFILE/REAL_WAZO_UPGRADE at
	# the top: override them only after sourcing
	PATH="$STUB_DIR:$PATH"
	LOGFILE="$BATS_TEST_TMPDIR/wazo-upgrade.log"
	REAL_WAZO_UPGRADE="$STUB_DIR/real-wazo-upgrade"
}

# apt-cache madison output lines matching '...Packages$' count as available packages
stub_apt_cache_madison_with_package() {
	local package=$1
	cat > "$STUB_DIR/apt-cache" <<-EOF
	#!/bin/bash
	echo "\$0 \$*" >> "$STUB_DIR/apt-cache.calls"
	if [ "\$1" = madison ] && [ "\$2" = "$package" ]; then
	    echo "$package | 1.0 | http://example/ Packages"
	fi
	EOF
	chmod +x "$STUB_DIR/apt-cache"
}

@test "check_package_is_available succeeds when apt-cache madison lists a Packages entry" {
	stub_apt_cache_madison_with_package bash

	run check_package_is_available bash

	[ "$status" -eq 0 ]
}

@test "check_package_is_available fails when apt-cache madison has no match" {
	stub_apt_cache_madison_with_package bash

	run check_package_is_available wazo-upgrade

	[ "$status" -ne 0 ]
}

@test "check_debian_mirror_is_available fails with a message when bash is unavailable" {
	stub_apt_cache_madison_with_package wazo-upgrade

	run check_debian_mirror_is_available

	[ "$status" -ne 0 ]
	[[ "$output" == *"Could not find any Debian repository"* ]]
}

@test "check_wazo_mirror_is_available fails with a message when wazo-upgrade is unavailable" {
	stub_apt_cache_madison_with_package bash

	run check_wazo_mirror_is_available

	[ "$status" -ne 0 ]
	[[ "$output" == *"Could not find any Wazo repository"* ]]
}

@test "run_upgrade stops before installing when the debian mirror is unavailable" {
	stub apt-get 0
	stub_apt_cache_madison_with_package wazo-upgrade
	stub real-wazo-upgrade 0

	run run_upgrade

	[ "$status" -ne 0 ]
	[ ! -f "$STUB_DIR/real-wazo-upgrade.calls" ]
}

@test "run_upgrade stops before installing when the wazo mirror is unavailable" {
	stub apt-get 0
	stub_apt_cache_madison_with_package bash
	stub real-wazo-upgrade 0

	run run_upgrade

	[ "$status" -ne 0 ]
	[ ! -f "$STUB_DIR/real-wazo-upgrade.calls" ]
}

@test "run_upgrade installs wazo-upgrade then delegates to real-wazo-upgrade" {
	stub apt-get 0
	stub apt-cache 0 "$(printf 'bash | 1.0 | http://example/ Packages\nwazo-upgrade | 1.0 | http://example/ Packages')"
	stub real-wazo-upgrade 0

	run run_upgrade -f

	[ "$status" -eq 0 ]
	grep -q 'install.*wazo-upgrade' "$STUB_DIR/apt-get.calls"
	grep -q -- '-f' "$STUB_DIR/real-wazo-upgrade.calls"
}

@test "append_log_start appends a start banner to the logfile" {
	append_log_start "$LOGFILE"

	grep -q 'wazo-upgrade started at' "$LOGFILE"
}

@test "append_log_end appends a stop banner to the logfile" {
	append_log_end "$LOGFILE"

	grep -q 'wazo-upgrade stopped at' "$LOGFILE"
}

@test "log_and_upgrade reports run_upgrade's exit status, not tee's" {
	# apt-cache lists neither package: the debian mirror check fails, so
	# run_upgrade returns 1 without touching the real apt-cache
	stub apt-get 0
	stub apt-cache 0

	run log_and_upgrade

	[ "$status" -eq 1 ]
	grep -q 'wazo-upgrade started at' "$LOGFILE"
	grep -q 'wazo-upgrade stopped at' "$LOGFILE"
	grep -q 'Could not find any Debian repository' "$LOGFILE"
}
