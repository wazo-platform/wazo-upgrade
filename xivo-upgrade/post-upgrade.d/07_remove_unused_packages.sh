#!/bin/bash
package="pf-xivo-agid"
dpkg -l $package | grep -q '^ii'
if [ $? = 0 ]; then
    apt-get remove --purge $package
fi
dpkg --list |grep "^rc" | cut -d " " -f 3 | xargs sudo dpkg --purge
