#!/bin/sh

set -e
set -u  # fail if variable is undefined

echo "Updating Wazo config"

xivo-create-config
xivo-update-config
