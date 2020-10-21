#!/bin/bash
# Copyright 2020 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
set -u  # fail if variable is undefined
set -o pipefail  # fail if command before pipe fails

wazo-confgen asterisk/pjsip.conf --invalidate
asterisk -rx 'module reload res_pjsip'
