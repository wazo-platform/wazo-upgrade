#!/bin/sh

# There was no personal contacts before 15.13
if [ "$XIVO_VERSION_INSTALLED" \< "15.13" ]; then
    exit 0
fi

# Personal contacts were stored in PG after version 16.05
if [ "$XIVO_VERSION_INSTALLED" \> "16.05" ]; then
    exit 0
fi

echo 'Migrating personal contacts to Postgresql...'
/usr/share/xivo-dird/migrations/0002_migrate_personal_contacts_from_consul_to_pg.py
if [ "$?" -ne "0" ]; then
    echo 'Migration failed.'
    echo 'All contacts have been preserved in consul but cannot be used by xivo-dird'
    echo 'To retry the later, use:'
    echo '/usr/share/xivo-dird/migrations/0002_migrate_personal_contacts_from_consul_to_pg.py'
fi
