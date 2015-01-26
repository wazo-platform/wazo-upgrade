#!/bin/bash

# Copyright (C) 2015 Avencall
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>


# Downgrade flask_restful and flask_restplus, following the upgrade of 15.01
# that uses flask_restful==0.3.1 and flask_restplus==0.4.0, which break Swagger
# UI provided by flask_resplus

apt-get install --yes --force-yes python-flask-restful=0.2.12 python-flask-restplus=0.2.4
