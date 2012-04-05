#!/bin/sh

su - -c "psql -c 'update linefeatures set num = 1 where num = 0;' asterisk" postgres
curl -s http://localhost/xivo/configuration/json.php/private/provisioning/configregistrar/?act=rebuild_required_config
