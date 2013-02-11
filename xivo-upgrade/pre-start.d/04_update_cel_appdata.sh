#!/bin/sh

is_executed_file="/var/lib/xivo-upgrade/$(basename $0)"

if [ -f "$is_executed_file" ]; then
    exit
else
    touch "$is_executed_file"
fi

su - -c 'psql -c "ALTER TABLE cel ALTER COLUMN appdata TYPE varchar(512);" asterisk > /dev/null' postgres
