#!/bin/bash

# This symlink is left over, after removing wazo-admin-ui and prevents nginx
# from loading correctly.

rm -f /etc/nginx/locations/https-enabled/wazo-admin-ui
