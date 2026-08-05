#!/bin/bash
# Copyright 2018-2026 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
set -u  # fail if variable is undefined
set -o pipefail  # fail if command before pipe fails

# || true: a failing trap command would override the script exit status
trap 'systemctl stop wazo-auth || true' EXIT

systemctl restart wazo-auth
wazo-auth-keys service update
wazo-auth-keys service clean --users
