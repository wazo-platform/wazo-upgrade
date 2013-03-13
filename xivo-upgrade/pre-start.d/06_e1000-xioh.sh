#!/bin/bash

cd /lib/modules
for kernel in *; do
    old_module=$kernel/xioh/e1000.ko
    if [ -f $old_module ]; then
        rm $old_module
        apt-get install e1000-xioh-modules-$kernel
    fi
done
