#!/usr/bin/python3
#
# This file is part of MagiskOnWSALocal.
#
# MagiskOnWSALocal is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# MagiskOnWSALocal is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with MagiskOnWSALocal.  If not, see <https://www.gnu.org/licenses/>.
#
# Copyright (C) 2023 LSPosed Contributors
#

import sys

import zipfile
from pathlib import Path

arch = sys.argv[1]

zip_name = ""
wsa_zip_path= Path(sys.argv[2])

with zipfile.ZipFile(wsa_zip_path) as zip:
    for f in zip.filelist:
        if arch in f.filename.lower():
            zip_name = f.filename
            break
ver_no = zip_name.split("_")
long_ver = ver_no[1]
ver = long_ver.split(".")
major_ver = ver[0]
print(major_ver)
