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
# Copyright (C) 2022 LSPosed Contributors
#

#!/usr/bin/python

import sys

import os
import json
import requests
from pathlib import Path

magisk_apk = sys.argv[1]
download_dir = Path.cwd().parent / "download" if sys.argv[2] == "" else Path(sys.argv[2]).resolve()
tempScript = sys.argv[3]
print(f"Generating Magisk download link: release type={magisk_apk}", flush=True)
if not magisk_apk:
    magisk_apk = "stable"
if magisk_apk == "stable" or magisk_apk == "beta" or magisk_apk == "canary" or magisk_apk == "debug":
    magisk_apk = json.loads(requests.get(
        f"https://github.com/topjohnwu/magisk-files/raw/master/{magisk_apk}.json").content)['magisk']['link']
print(f"download link: {magisk_apk}", flush=True)
out_file = download_dir / "magisk.zip"

if not os.path.isfile(out_file):
    # urllib.request.urlretrieve(magisk_apk, out_file)
    with open(download_dir/tempScript, 'a') as f:
        f.writelines(f'{magisk_apk}\n')
        f.writelines(f'  dir={download_dir}\n')
        f.writelines(f'  out=magisk.zip\n')
