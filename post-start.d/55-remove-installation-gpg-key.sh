#!/bin/bash
# Copyright 2021 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
set -u  # fail if variable is undefined
set -o pipefail  # fail if command before pipe fails

SENTINEL="/var/lib/wazo-upgrade/remove-installation-gpg-key"

[ -e "${SENTINEL}" ] && exit 0

apt-key remove --keyring /etc/apt/trusted.gpg 2769B67EDBFF423F6874D7663F1BF7FC527FBC6A

touch "${SENTINEL}"
