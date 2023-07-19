#!/usr/bin/env python3
# Copyright 2023 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

import logging
import os
import os.path
import shutil
import sys
import wave

from wazo_auth_client import Client as AuthClient
from wazo_confd_client import Client as ConfdClient
from xivo.chain_map import ChainMap
from xivo.config_helper import read_config_file_hierarchy, parse_config_file

SENTINEL = "/var/lib/wazo-upgrade/remove-wrong-format-moh"
_DEFAULT_CONFIG = {
    "config_file": "/etc/wazo-upgrade/config.yml",
    "auth": {"key_file": "/var/lib/wazo-auth-keys/wazo-upgrade-key.yml"},
}

MOH_PATH = "/var/lib/asterisk/moh"
INVALID_MOH_PATH = "/var/lib/asterisk/moh/.invalid"

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("remove_wrong_format_moh")


def load_config():
    file_config = read_config_file_hierarchy(_DEFAULT_CONFIG)
    key_config = _load_key_file(ChainMap(file_config, _DEFAULT_CONFIG))
    return ChainMap(key_config, file_config, _DEFAULT_CONFIG)


def _load_key_file(config):
    key_file = parse_config_file(config["auth"]["key_file"])
    return {
        "auth": {
            "username": key_file["service_id"],
            "password": key_file["service_key"],
        }
    }


class InvalidWAVFileException(Exception):
    def __init__(self, message, wav_file, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.message = message
        self.wav_file = wav_file

    def __str__(self):
        return f'Invalid WAV file "{self.wav_file}": {self.message}'


def find_moh_files(confd_client):
    all_files = []
    all_moh = confd_client.moh.list(recurse=True)["items"]

    for moh in all_moh:
        if moh["name"] == "default":
            # NOTE(afournier): we do not want to touch the system-provided MOH class
            continue
        if moh["mode"] != "files":
            continue
        for moh_file in moh["files"]:
            filename = os.path.join(MOH_PATH, moh["name"], moh_file["name"])
            orig_filename = moh_file["name"]
            all_files.append(
                {
                    "uuid": moh["uuid"],
                    "filename": filename,
                    "orig_filename": orig_filename,
                    "name": moh["name"],
                }
            )
    return all_files


def validate_wav_file(wav_file):
    try:
        with wave.open(wav_file["filename"], "rb") as f:
            if f.getnchannels() > 1:
                raise InvalidWAVFileException(
                    "Audio file should be mono", wav_file=wav_file["filename"]
                )
            if f.getframerate() != 8000 and f.getframerate() != 16000:
                raise InvalidWAVFileException(
                    "Audio file should have a sample rate of 8kHz or 16kHz",
                    wav_file["filename"],
                )
            if f.getsampwidth() > 2:
                raise InvalidWAVFileException(
                    "Audio file should have bit depth of no more than 16 bits",
                    wav_file["filename"],
                )
    except Exception as e:
        raise InvalidWAVFileException(
            f'Cannot read WAV file: "{e}"', wav_file=wav_file["filename"]
        )


def validate_wav_files(confd_client, files):
    invalid_files = []
    for wav_file in files:
        try:
            validate_wav_file(wav_file)
        except InvalidWAVFileException as e:
            logger.debug('Invalid file "%s": %s', wav_file, e.message)
            invalid_files.append(wav_file)
    return invalid_files


def handle_invalid_file(confd_client, invalid_file):
    destination_directory_name = "-".join([invalid_file["name"], invalid_file["uuid"]])
    invalid_destination_path = os.path.join(
        INVALID_MOH_PATH, destination_directory_name
    )
    if not os.path.exists(invalid_destination_path):
        os.makedirs(invalid_destination_path)
    shutil.copy2(invalid_file["filename"], invalid_destination_path)
    confd_client.moh.delete_file(invalid_file["uuid"], invalid_file["orig_filename"])


def main():
    if os.path.exists(SENTINEL):
        sys.exit(0)

    config = load_config()
    auth_client = AuthClient(**config["auth"])
    token_data = auth_client.token.new(expiration=600)
    confd_client = ConfdClient(token=token_data["token"], **config["confd"])

    files = find_moh_files(confd_client)
    invalid_files = validate_wav_files(confd_client, files)

    if invalid_files:
        print(
            f'*** WARNING ***\nThe following files are invalid and will be moved to "{INVALID_MOH_PATH}"'
        )
        for invalid_file in invalid_files:
            print(f"- {invalid_file['name']}: {invalid_file['filename']}")
            handle_invalid_file(confd_client, invalid_file)

    with open(SENTINEL, "w") as f:
        f.write("")


if __name__ == "__main__":
    main()
