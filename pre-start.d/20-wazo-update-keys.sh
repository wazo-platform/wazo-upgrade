#!/bin/bash
# Copyright 2018-2020 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
set -u  # fail if variable is undefined
set -o pipefail  # fail if command before pipe fails

systemctl restart wazo-auth
wazo-auth-keys service update
wazo-auth-keys service clean --users
systemctl stop wazo-auth
