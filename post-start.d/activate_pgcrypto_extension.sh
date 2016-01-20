#!/bin/bash

if [ "$XIVO_VERSION_INSTALLED" \> '15.20' ]; then
    exit 0
fi

su - -c "psql -c 'create extension if not exists pgcrypto;' asterisk > /dev/null 2>&1" postgres
