# Copyright 2026 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

"""Merges mappings, first argument winning, as the real one does."""

from typing import Any


class ChainMap(dict):
    def __init__(self, *maps: dict[str, Any]) -> None:
        merged: dict[str, Any] = {}
        for one in reversed(maps):
            merged.update(one or {})
        super().__init__(merged)
