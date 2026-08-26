# Copyright 2026 The Wazo Authors  (see the AUTHORS file)
# SPDX-License-Identifier: GPL-3.0-or-later

"""Hands out a token, which is all a post-start script asks of it."""

from typing import Any


class _Token:
    def new(self, **kwargs: Any) -> dict[str, str]:
        return {'token': 'a-token'}


class Client:
    def __init__(self, **kwargs: Any) -> None:
        self.token = _Token()
