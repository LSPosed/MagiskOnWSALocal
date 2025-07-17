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
# Copyright (C) 2025 LSPosed Contributors
#
import sys
from pathlib import Path

arch = sys.argv[1]
arg2 = sys.argv[2]
download_dir = Path.cwd().parent / "download" if arg2 == "" else Path(arg2)
tempScript = sys.argv[3]
android_api = sys.argv[4]
file_name = sys.argv[5]
print(f"Generating GApps download link: arch={arch}", flush=True)
abi_map = {"x64": "x86_64", "arm64": "arm64"}
android_api_map = {"30": "11.0", "32": "12.1", "33": "13.0"}
release = android_api_map[android_api]
download_files = {}
download_files[f"gapps-{release}.rc"] = f"https://github.com/LSPosed/WSA-Addon/releases/latest/download/gapps-{release}.rc"
download_files[f"gapps-{release}-{abi_map[arch]}.img"] = f"https://github.com/LSPosed/WSA-Addon/releases/latest/download/gapps-{release}-{abi_map[arch]}.img"
with open(download_dir / tempScript, "a") as f:
    for key, value in download_files.items():
        print(f"download link: {value}\npath: {download_dir / key}\n", flush=True)
        f.writelines(value + "\n")
        f.writelines(f"  dir={download_dir}\n")
        f.writelines(f"  out={key}\n")
