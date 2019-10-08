#!/bin/bash

set -e
set -u  # fail if variable is undefined
set -o pipefail  # fail if command before pipe fails

# This symlink is left over, after removing wazo-admin-ui and prevents nginx
# from loading correctly.

rm -f /etc/nginx/locations/https-enabled/wazo-admin-ui
