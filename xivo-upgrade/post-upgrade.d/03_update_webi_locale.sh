#!/bin/sh

xivo_ini_path='/etc/pf-xivo/web-interface/xivo.ini'

if [ -f "$xivo_ini_path" ]; then
    sed -i -e 's/^language = fr/language = en/' -e 's/^territory = FR/territory = US/' "$xivo_ini_path"
fi
