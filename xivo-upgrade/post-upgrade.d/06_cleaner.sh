#!/bin/sh

XIVO_WEBI_LIB_PATH=" /var/lib/pf-xivo-web-interface"

LIST_TOCLEAN="${XIVO_WEBI_LIB_PATH}/statistics
		${XIVO_WEBI_LIB_PATH}/pchart"

for TOCLEANUP in ${LIST_TOCLEAN}; do
    if [ -d "${TOCLEANUP}" ]; then
	    rm -rf "${TOCLEANUP}"
    fi
done
