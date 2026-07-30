#!/usr/bin/env bats
# Copyright 2026 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

load ../test_helper

setup() {
	export CONFIGS_DIR="$BATS_TEST_TMPDIR/configs"
	mkdir -p "$CONFIGS_DIR"
	SCRIPT="$REPO_ROOT/pre-start.d/30-fix-provd-deletable-configs.sh"
}

@test "restores deletable=false on a wizard config that was flipped to true" {
	echo '{"id": "base", "deletable": true}' > "$CONFIGS_DIR/base"

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[[ "$output" == *"Restoring deletable=false on $CONFIGS_DIR/base"* ]]
	[ "$(jq -r '.deletable' "$CONFIGS_DIR/base")" = 'false' ]
}

@test "leaves a wizard config alone when deletable is already false" {
	echo '{"id": "default", "deletable": false}' > "$CONFIGS_DIR/default"
	local before
	before="$(md5sum "$CONFIGS_DIR/default")"

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[[ "$output" != *Restoring* ]]
	[ "$(md5sum "$CONFIGS_DIR/default")" = "$before" ]
}

@test "preserves the rest of the config's JSON content when fixing deletable" {
	echo '{"id": "autoprov", "deletable": true, "label": "Autoprovisioning"}' > "$CONFIGS_DIR/autoprov"

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ "$(jq -c -S . "$CONFIGS_DIR/autoprov")" = '{"deletable":false,"id":"autoprov","label":"Autoprovisioning"}' ]
}

@test "ignores configs that are not one of the four wizard configs" {
	echo '{"id": "custom", "deletable": true}' > "$CONFIGS_DIR/custom"

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ "$(jq -r '.deletable' "$CONFIGS_DIR/custom")" = 'true' ]
}

@test "does nothing when a wizard config file does not exist" {
	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "does nothing when the configs directory itself does not exist" {
	export CONFIGS_DIR="$BATS_TEST_TMPDIR/does-not-exist"

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "does not leave a temp file behind after fixing a config" {
	echo '{"id": "base", "deletable": true}' > "$CONFIGS_DIR/base"

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ "$(ls -1A "$CONFIGS_DIR" | grep -c '^\.')" -eq 0 ]
}
