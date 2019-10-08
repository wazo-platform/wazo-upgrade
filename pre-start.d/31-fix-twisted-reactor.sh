#!/bin/bash

set -e
set -u  # fail if variable is undefined
set -o pipefail  # fail if command before pipe fails

twistd >/dev/null
