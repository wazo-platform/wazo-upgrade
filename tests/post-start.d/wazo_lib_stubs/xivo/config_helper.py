# Copyright 2026 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

"""Answers what a post-start script reads out of /etc and /var/lib.

The dird port comes from `FAKE_DIRD_PORT`: a test starts its mock on a free
port, and this is where a script picks a port up in a real deployment too.
"""

import os
from typing import Any


def read_config_file_hierarchy(default: dict[str, Any]) -> dict[str, Any]:
    return {
        'dird': {
            'host': '127.0.0.1',
            'port': int(os.environ['FAKE_DIRD_PORT']),
            'version': '0.1',
            'prefix': None,
            'https': False,
        }
    }


def parse_config_file(path: str) -> dict[str, str]:
    return {'service_id': 'an-id', 'service_key': 'a-key'}
