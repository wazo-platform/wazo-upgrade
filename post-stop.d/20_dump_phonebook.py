#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Copyright 2016-2017 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0+


from __future__ import print_function

import os
import psycopg2
import sys
import json

from contextlib import closing

DB_DSN = 'dbname=asterisk user=asterisk password=proformatique host=localhost'


def _read_old_phonebook(cur):
    phonebook_fields = [
        'id',
        'title',
        'firstname',
        'lastname',
        'displayname',
        'society',
        'email',
        'url',
        'description',
    ]
    phonebook_number_fields = [
        'phonebookid',
        'number',
        'type',
    ]
    phonebook_address_fields = [
        'phonebookid',
        'type',
        'address1',
        'address2',
        'city',
        'state',
        'zipcode',
        'country',
    ]

    contacts = {}

    try:
        cur.execute('SELECT 1 FROM "phonebook"')
    except psycopg2.ProgrammingError as e:
        # The phonebook has already been migrated
        sys.exit(0)

    cur.execute('SELECT {} FROM "phonebook"'.format(','.join(phonebook_fields)))
    for row in cur.fetchall():
        id, title, firstname, lastname, displayname, society, email, url, description = row
        contacts[id] = {
            'title': title,
            'firstname': firstname,
            'lastname': lastname,
            'displayname': displayname,
            'society': society,
            'email': email,
            'url': url,
            'description': description,
        }

    if not contacts:
        return []

    cur.execute("""SELECT {} FROM "phonebooknumber" """.format(','.join(phonebook_number_fields)))
    for row in cur.fetchall():
        id, number, type_ = row
        if id not in contacts:
            continue
        contacts[id]['number_{}'.format(type_)] = number

    cur.execute("""SELECT {} FROM "phonebookaddress" """.format(','.join(phonebook_address_fields)))
    for row in cur.fetchall():
        id, type_, address1, address2, city, state, zipcode, country = row
        if id not in contacts:
            continue

        for field in phonebook_address_fields[2:]:  # id and type_ are not part of the contact
            value = locals().get(field)
            if not value:
                continue
            contacts[id]['address_{}_{}'.format(type_, field)] = value

    return contacts.values()


def _list_entities(cur):
    cur.execute("""SELECT "name" FROM "entity" where "disable" = 0 """)
    return [row[0] for row in cur.fetchall()]


def _save_to_file(phonebook, entities, filename):
    if not entities:
        return

    print('saving phonebook to {}'.format(filename), end='... ')

    with open(filename, 'w') as f:
        json.dump([entities, phonebook], f)

    print('done.')


if __name__ == '__main__':
    if os.getenv('XIVO_VERSION_INSTALLED') > '16.14':
        sys.exit(0)

    entity_dsn = DB_DSN
    if os.getenv('XIVO_VERSION_INSTALLED') < '14.08':
        entity_dsn = 'dbname=xivo user=xivo password=proformatique host=localhost'

    phonebook_filename = '/var/lib/xivo-upgrade/phonebook_dump.json'
    if os.path.exists(phonebook_filename):
        sys.exit(0)

    with closing(psycopg2.connect(DB_DSN)) as conn:
        phonebook_content = _read_old_phonebook(conn.cursor()) or []

    with closing(psycopg2.connect(entity_dsn)) as conn:
        entities = _list_entities(conn.cursor()) or []

    _save_to_file(phonebook_content, entities, phonebook_filename)