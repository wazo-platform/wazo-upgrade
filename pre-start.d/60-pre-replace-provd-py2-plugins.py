#!/usr/bin/env python3
# Copyright 2022 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later
import logging
import os
import shutil
import sys
from distutils.dir_util import copy_tree
from xivo.config_helper import read_config_file_hierarchy, parse_config_file


logger = logging.getLogger('pre_replace_py2_provd_plugins')
logging.basicConfig(level=logging.INFO)

_DEFAULT_CONFIG = {
    'config_file': '/etc/wazo-upgrade/config.yml',
    'auth': {
        'key_file': '/var/lib/wazo-auth-keys/wazo-upgrade-key.yml'
    }
}
DEFAULT_PLUGIN_DIR = '/var/lib/wazo-provd/plugins/'
SENTINEL_FILE = '/var/lib/wazo-upgrade/pre-replace-provd-py2-plugins'


def rename_xivo_plugins(plugin_dir):
    for old_plugin_name in os.listdir(plugin_dir):
        new_plugin_name = old_plugin_name.replace('xivo-', 'wazo-')
        source_dir = os.path.join(plugin_dir, old_plugin_name)
        target_dir = os.path.join(plugin_dir, new_plugin_name)
        if os.path.exists(source_dir):
            # If there was both a wazo- and a xivo- version copy the contents from the xivo one
            for file_name in os.listdir(source_dir):
                if file_name == 'build.py':
                    # Skip this file, it will be replaced anyway on upgrade
                    continue
                if file_name == 'common' and old_plugin_name == 'xivo-gigaset':
                    file_name = 'common-c'
                    os.rename(os.path.join(source_dir, 'common'), os.path.join(source_dir, 'common-c'))
                source = os.path.join(source_dir, file_name)
                target = os.path.join(target_dir, file_name)
                if os.path.isdir(source) and os.path.exists(target) and os.path.isdir(target):
                    copy_tree(source, target)
                elif not os.path.isdir(target):
                    continue
                else:
                    shutil.move(source, target_dir)
            shutil.rmtree(source_dir)
        else:
            os.rename(source_dir, target_dir)


def main():
    if os.path.exists(SENTINEL_FILE):
        sys.exit(0)

    config = read_config_file_hierarchy(_DEFAULT_CONFIG)['provd']
    general_config = config.get('general', {})
    plugin_dir = general_config.get('base_storage_dir', DEFAULT_PLUGIN_DIR)

    rename_xivo_plugins(plugin_dir)

    with open(SENTINEL_FILE, 'w'):
        pass


if __name__ == '__main__':
    main()
