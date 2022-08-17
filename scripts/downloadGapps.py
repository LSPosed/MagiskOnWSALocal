#!/usr/bin/python

import sys

import requests
import zipfile
import os
import urllib.request
import json
import re
from pathlib import Path

if not os.path.exists(Path.cwd().parent / "download"):
    os.makedirs(Path.cwd().parent / "download")
download_dir = Path.cwd().parent / "download"

arch = sys.argv[1]
# TODO: Keep it pico since other variants of opengapps are unable to boot successfully
variant = sys.argv[2] if 0 else "pico"
abi_map = {"x64": "x86_64", "arm64": "arm64"}
# TODO: keep it 11.0 since opengapps does not support 12+ yet
# As soon as opengapps is available for 12+, we need to get the sdk/release from build.prop and
# download the corresponding version
release = "11.0"
try:
    res = requests.get(f"https://api.opengapps.org/list")
    j = json.loads(res.content)
    link = {i["name"]: i for i in j["archs"][abi_map[arch]]
            ["apis"][release]["variants"]}[variant]["zip"]
except Exception:
    print("Failed to fetch from opengapps api, fallbacking to sourceforge rss...")
    res = requests.get(
        f'https://sourceforge.net/projects/opengapps/rss?path=/{abi_map[arch]}&limit=100')
    link = re.search(f'https://.*{abi_map[arch]}/.*{release}.*{variant}.*\.zip/download', res.text).group().replace(
        '.zip/download', '.zip').replace('sourceforge.net/projects/opengapps/files', 'downloads.sourceforge.net/project/opengapps')

print(f"downloading link: {link}", flush=True)

out_file = download_dir / "gapps.zip"

if not os.path.isfile(out_file):
    urllib.request.urlretrieve(link, out_file)
