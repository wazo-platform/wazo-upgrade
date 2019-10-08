#!/bin/bash
# Copyright 2013-2019 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
set -u  # fail if variable is undefined
set -o pipefail  # fail if command before pipe fails

PATH=/bin:/usr/bin:/sbin:/usr/sbin

xivo-fix-paths-rights
