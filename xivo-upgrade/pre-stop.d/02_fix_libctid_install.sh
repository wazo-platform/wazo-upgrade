#!/bin/bash
file="/var/lib/dpkg/info/xivo-ctid.list"
grep -q pyshared $file
if [ $? -eq 0 ]; then
    sed -i '/.*pyshared.*/d' $file
fi
