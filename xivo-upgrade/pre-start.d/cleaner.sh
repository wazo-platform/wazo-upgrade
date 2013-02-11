#!/bin/sh

LIST_DIR_TOCLEAN="/var/lib/pf-xivo-web-interface"

LIST_FILE_TOCLEAN="/etc/pf-xivo/web-interface/location.ini
                   /etc/pf-xivo/web-interface/report.ini
                   /etc/pf-xivo/web-interface/template.ini
                   /etc/cron.d/pf-xivo-web-interface
                   /etc/default/xivo-agent
                   /etc/default/xivo-ctid"

for DIR in ${LIST_DIR_TOCLEAN}; do
    if [ -d "${DIR}" ]; then
        rm -rf "${DIR}"
    fi
done

for FILE in ${LIST_FILE_TOCLEAN}; do
    if [ -f "${FILE}" ]; then
        rm -f "${FILE}"
    fi
done
