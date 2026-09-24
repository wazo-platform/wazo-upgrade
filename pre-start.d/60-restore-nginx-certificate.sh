#!/bin/bash
# Copyright 2026 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
set -u  # fail if variable is undefined
set -o pipefail  # fail if command before pipe fails

SITE="${WAZO_UPGRADE_ROOT:-}/etc/nginx/sites-available/wazo"
SITE_OLD="${SITE}.dpkg-old"
DEFAULT_CERTIFICATE='/usr/share/wazo-certs/server.crt'
DEFAULT_KEY='/usr/share/wazo-certs/server.key'

directive_value() {
    local directive=$1 file=$2
    sed -n -E "/^[[:space:]]*${directive}[[:space:]]/{s/^[[:space:]]*${directive}[[:space:]]+([^;[:space:]]+);.*/\1/p;q}" "$file"
}

replace_directive_value() {
    local directive=$1 value=$2 file=$3
    sed -i -E "s|^([[:space:]]*${directive}[[:space:]]+)[^;]+;|\1${value};|" "$file"
}

[ -f "$SITE_OLD" ] || exit 0
[ "$(directive_value ssl_certificate "$SITE")" = "$DEFAULT_CERTIFICATE" ] || exit 0
[ "$(directive_value ssl_certificate_key "$SITE")" = "$DEFAULT_KEY" ] || exit 0

old_certificate="$(directive_value ssl_certificate "$SITE_OLD")"
old_key="$(directive_value ssl_certificate_key "$SITE_OLD")"
[ -n "$old_certificate" ] && [ -n "$old_key" ] || exit 0
[ "$old_certificate" != "$DEFAULT_CERTIFICATE" ] || [ "$old_key" != "$DEFAULT_KEY" ] || exit 0
[ -f "${WAZO_UPGRADE_ROOT:-}${old_certificate}" ] && [ -f "${WAZO_UPGRADE_ROOT:-}${old_key}" ] || exit 0

echo "Restoring the nginx certificate from ${SITE_OLD}"
backup="$(mktemp --tmpdir="${WAZO_UPGRADE_ROOT:-}/tmp" wazo-nginx-site.XXXXXX)"
cp -p "$SITE" "$backup"
replace_directive_value ssl_certificate "$old_certificate" "$SITE"
replace_directive_value ssl_certificate_key "$old_key" "$SITE"

if ! nginx -t; then
    cp -p "$backup" "$SITE"
    rm -f "$backup"
    echo "WARNING: nginx rejected the restored certificate, ${SITE} keeps the default one"
    exit 0
fi
rm -f "$backup"
systemctl try-reload-or-restart nginx || echo "WARNING: could not reload nginx, run 'systemctl reload nginx' to apply the restored certificate"
