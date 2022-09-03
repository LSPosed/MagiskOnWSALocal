#!/usr/bin/python
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

import sys

import requests
import json
import re
from pathlib import Path

arch = sys.argv[1]
brand = sys.argv[2]
variant = sys.argv[3]
download_dir = Path.cwd().parent / \
    "download" if sys.argv[4] == "" else Path(sys.argv[4]).resolve()
tempScript = sys.argv[5]
print(
    f"Generating {brand} download link: arch={arch} variant={variant}", flush=True)
abi_map = {"x64": "x86_64", "arm64": "arm64"}
# TODO: get the sdk/release from build.prop and download the corresponding version
release = "12L"
if brand == "OpenGApps":
    try:
        res = requests.get(f"https://api.opengapps.org/list")
        j = json.loads(res.content)
        link = {i["name"]: i for i in j["archs"][abi_map[arch]]
                ["apis"][release]["variants"]}[variant]["zip"]
        DATE=j["archs"][abi_map[arch]]["date"]
        print(f"DATE={DATE}", flush=True)
    except Exception:
        print("Failed to fetch from OpenGApps API, fallbacking to SourceForge RSS...")
        res = requests.get(
            f'https://sourceforge.net/projects/opengapps/rss?path=/{abi_map[arch]}&limit=100')
        link = re.search(f'https://.*{abi_map[arch]}/.*{release}.*{variant}.*\.zip/download', res.text).group().replace(
            '.zip/download', '.zip').replace('sourceforge.net/projects/opengapps/files', 'downloads.sourceforge.net/project/opengapps')
elif brand == "MindTheGapps":
    res = requests.get(
        f'https://sourceforge.net/projects/wsa-mtg/rss?path=/{abi_map[arch]}&limit=100')
    link = re.search(f'https://.*{abi_map[arch]}/.*\.zip/download', res.text).group().replace(
        '.zip/download', '.zip').replace('sourceforge.net/projects/wsa-mtg/files', 'downloads.sourceforge.net/project/wsa-mtg')

print(f"download link: {link}", flush=True)

with open(download_dir/tempScript, 'a') as f:
    f.writelines(f'{link}\n')
    f.writelines(f'  dir={download_dir}\n')
    if brand == "OpenGApps":
        f.writelines(f'  out={brand}-{arch}-{variant}.zip\n')
    elif brand == "MindTheGapps":
        f.writelines(f'  out={brand}-{arch}.zip\n')
    f.close
