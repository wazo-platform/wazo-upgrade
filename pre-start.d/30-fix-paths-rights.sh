#!/bin/bash

set -e
set -u  # fail if variable is undefined
set -o pipefail  # fail if command before pipe fails

PATH=/bin:/usr/bin:/sbin:/usr/sbin

xivo-fix-paths-rights
