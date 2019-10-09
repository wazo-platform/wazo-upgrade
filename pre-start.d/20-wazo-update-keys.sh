#!/bin/bash
# Copyright 2018 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

wait_until_ready(){
    WAIT_TIMEOUT=60
    WAIT_INTERVAL=1
    while ! ss --listening --tcp '( sport = :9497 )' | grep -q LISTEN; do
        sleep ${WAIT_INTERVAL}
        WAIT_TIMEOUT=$((WAIT_TIMEOUT - WAIT_INTERVAL))
        if [ "$WAIT_TIMEOUT" -eq 0 ]; then
            echo "wazo-auth is not ready"
            return 1
        fi
    done
}

systemctl restart wazo-auth
wait_until_ready
if [ $? -ne 0 ]; then
    echo "Cannot update service key, please fix wazo-auth and re-run wazo-upgrade"
    exit -1
fi
wazo-auth-keys service update
wazo-auth-keys service clean --users
systemctl stop wazo-auth
