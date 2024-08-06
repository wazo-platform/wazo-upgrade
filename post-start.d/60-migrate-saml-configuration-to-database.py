#!/usr/bin/env python3
# Copyright 2024 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

import logging
import os
import os.path
import sys
from typing import Any

from wazo_auth_client import Client as AuthClient
from xivo.chain_map import AccumulatingListChainMap, ChainMap
from xivo.config_helper import (parse_config_file, read_config_file_hierarchy,
                                read_config_file_hierarchy_accumulating_list)

SENTINEL = "/var/lib/wazo-upgrade/migrate-saml-configuration-to-database"

_DEFAULT_CONFIG = {
    "config_file": "/etc/wazo-upgrade/config.yml",
    "auth": {"key_file": "/var/lib/wazo-auth-keys/wazo-upgrade-key.yml"},
}

WAZO_AUTH_CONFIG_FILE = "/etc/wazo-auth/config.yml"

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("migrate-saml-configuration-to-database")

RawSAMLConfig = dict[str, Any]


def load_config():
    file_config = read_config_file_hierarchy(_DEFAULT_CONFIG)
    key_config = _load_key_file(
        ChainMap(file_config, _DEFAULT_CONFIG)
    )
    return ChainMap(key_config, file_config, _DEFAULT_CONFIG)


def _load_key_file(config):
    key_file = parse_config_file(config["auth"]["key_file"])
    return {
        "auth": {
            "username": key_file["service_id"],
            "password": key_file["service_key"],
        }
    }


def extract_saml_configuration():
    wazo_auth_config: AccumulatingListChainMap = (
        read_config_file_hierarchy_accumulating_list(
            {"config_file": WAZO_AUTH_CONFIG_FILE}
        )
    )
    return wazo_auth_config.get('saml')


def get_domain_uuid(auth_client, domain_name, tenant_uuid):
    domains = auth_client.tenants.get_domains(tenant_uuid)
    for domain in domains["items"]:
        if domain["name"] == domain_name:
            return domain["uuid"]


def add_uuids_from_domain(client, saml_config):
    for domain in saml_config["domains"]:
        tenant = client.tenants.list(None, search=domain)
        if tenant["filtered"] == 1:
            tenant_uuid = tenant["items"][0]["uuid"]
            domain_uuid = get_domain_uuid(
                client,
                domain, 
                tenant_uuid
            )
            saml_config["domains"][domain]["tenant_uuid"] = tenant_uuid
            saml_config["domains"][domain]["domain_uuid"] = domain_uuid
    return saml_config


def create_saml_config_in_db(auth_client, saml_config):
    for domain in saml_config["domains"]:
        domain_data = saml_config["domains"][domain]
        tenant_uuid = domain_data["tenant_uuid"]
        metadata_file = domain_data["metadata"]["local"][0]
        metadata = open(metadata_file).read()
        config = {
            "data": {
                "acs_url": domain_data["service"]["sp"]["endpoints"][
                    "assertion_consumer_service"
                ][0][0],
                "entity_id": domain_data["entityid"],
                "domain_uuid": domain_data["domain_uuid"],
            },
            "files": {"metadata": metadata},
        }
        auth_client.saml_config.create(tenant_uuid, **config)
        logger.info(
            'Migrated SAML authentication configuration for domain "%s" to database, config: %s',
            domain,
            domain_data,
        )


def main():
    if os.path.exists(SENTINEL):
        sys.exit(0)

    config = load_config()
    auth_client = AuthClient(**config["auth"])
    token_data = auth_client.token.new(expiration=600)
    auth_client.set_token(token_data["token"])

    try:
        saml_config = extract_saml_configuration()
        if saml_config:
            saml_config_with_domain = add_uuids_from_domain(
                auth_client,
                saml_config
            )
            create_saml_config_in_db(auth_client, saml_config_with_domain)

        with open(SENTINEL, "w") as f:
            f.write("")

    except Exception as e:
        msg = f"Failed to migrate SAML configuration to database because of {e}"
        logger.exception(
            f"Failed to migrate SAML configuration to database because of {e}"
        )
        print(msg)


if __name__ == "__main__":
    main()
