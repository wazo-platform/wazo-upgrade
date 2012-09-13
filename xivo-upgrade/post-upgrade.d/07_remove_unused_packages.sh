#!/bin/bash
package="pf-xivo-agid"
dpkg -l $package | grep -q '^ii'
if [ $? = 0 ]; then
    apt-get remove --purge $package
fi
