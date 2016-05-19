#!/bin/sh

set -e

# There was no favorite storage before 15.12
if [ "$XIVO_VERSION_INSTALLED" \< "15.12" ]; then
    exit 0
fi

# Favorites were stored in PG after version 16.06
if [ "$XIVO_VERSION_INSTALLED" \> "16.06" ]; then
    exit 0
fi

echo 'Migrating favorites to Postgresql...'
/usr/share/xivo-dird/migrations/0003_migrate_favorites_from_consul_to_pg.py
