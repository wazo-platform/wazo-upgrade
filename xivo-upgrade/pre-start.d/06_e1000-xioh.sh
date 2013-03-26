#!/bin/bash

cd /lib/modules
for kernel in *; do
    old_module=$kernel/xioh/e1000.ko
    if [ -f $old_module ]; then
        apt-get install -y e1000-xioh-modules-$kernel && rm $old_module
    fi
done
