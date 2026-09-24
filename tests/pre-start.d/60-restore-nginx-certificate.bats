#!/usr/bin/env bats
# Copyright 2026 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

load ../test_helper

setup() {
	fake_root_setup
	stub_path_setup
	stub nginx 0
	stub systemctl 0
	SITE="$WAZO_UPGRADE_ROOT/etc/nginx/sites-available/wazo"
	SCRIPT="$REPO_ROOT/pre-start.d/60-restore-nginx-certificate.sh"
	mkdir -p "$WAZO_UPGRADE_ROOT/etc/letsencrypt/live/wazo.example.com"
	touch "$WAZO_UPGRADE_ROOT/etc/letsencrypt/live/wazo.example.com/fullchain.pem" \
		"$WAZO_UPGRADE_ROOT/etc/letsencrypt/live/wazo.example.com/privkey.pem"
}

write_site() {
	local file=$1 certificate=$2 key=$3
	cat > "$file" <<-EOF
	server {
	    listen 443 default_server ssl;
	    ssl_certificate ${certificate};
	    ssl_certificate_key ${key};
	    ssl_protocols TLSv1.2 TLSv1.3;
	}
	EOF
}

write_default_site() {
	write_site "$SITE" /usr/share/wazo-certs/server.crt /usr/share/wazo-certs/server.key
}

write_custom_site_old() {
	write_site "$SITE.dpkg-old" \
		'/etc/letsencrypt/live/wazo.example.com/fullchain.pem; # managed by Certbot' \
		'/etc/letsencrypt/live/wazo.example.com/privkey.pem; # managed by Certbot'
}

@test "restores the custom certificate from the .dpkg-old site and reloads nginx" {
	write_default_site
	write_custom_site_old

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[[ "$output" == *"Restoring the nginx certificate"* ]]
	grep -qx '    ssl_certificate /etc/letsencrypt/live/wazo.example.com/fullchain.pem;' "$SITE"
	grep -qx '    ssl_certificate_key /etc/letsencrypt/live/wazo.example.com/privkey.pem;' "$SITE"
	grep -qx '    ssl_protocols TLSv1.2 TLSv1.3;' "$SITE"
	grep -q 'try-reload-or-restart nginx' "$STUB_DIR/systemctl.calls"
}

@test "does nothing when there is no .dpkg-old site" {
	write_default_site
	local before
	before="$(md5sum "$SITE")"

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ -z "$output" ]
	[ "$(md5sum "$SITE")" = "$before" ]
	[ "$(stub_call_count nginx)" -eq 0 ]
}

@test "leaves a site that already has a custom certificate untouched" {
	write_site "$SITE" /etc/ssl/other.crt /etc/ssl/other.key
	write_custom_site_old
	local before
	before="$(md5sum "$SITE")"

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ "$(md5sum "$SITE")" = "$before" ]
	[ "$(stub_call_count nginx)" -eq 0 ]
}

@test "does nothing when the .dpkg-old site had the default certificate" {
	write_default_site
	write_site "$SITE.dpkg-old" /usr/share/wazo-certs/server.crt /usr/share/wazo-certs/server.key

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ "$(stub_call_count nginx)" -eq 0 ]
}

@test "does nothing when the old certificate file no longer exists" {
	write_default_site
	write_custom_site_old
	rm "$WAZO_UPGRADE_ROOT/etc/letsencrypt/live/wazo.example.com/fullchain.pem"
	local before
	before="$(md5sum "$SITE")"

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[ "$(md5sum "$SITE")" = "$before" ]
	[ "$(stub_call_count nginx)" -eq 0 ]
}

@test "keeps the default certificate and warns when nginx rejects the restored one" {
	stub nginx 1
	write_default_site
	write_custom_site_old
	local before
	before="$(md5sum "$SITE")"

	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[[ "$output" == *"WARNING: nginx rejected the restored certificate"* ]]
	[ "$(md5sum "$SITE")" = "$before" ]
	[ "$(stub_call_count systemctl)" -eq 0 ]
	[ -z "$(ls -A "$WAZO_UPGRADE_ROOT/tmp")" ]
}
