#!/usr/bin/python

import sys

import urllib.request
import zipfile
import os
import json
import requests
from pathlib import Path

magisk_apk = sys.argv[2]

if not os.path.exists(Path.cwd().parent / "download"):
    os.makedirs(Path.cwd().parent / "download")
download_dir = Path.cwd().parent / "download"

if not os.path.exists(Path.cwd().parent / sys.argv[3] / "magisk"):
    os.makedirs(Path.cwd().parent / sys.argv[3] / "magisk")
workdir = Path.cwd().parent / sys.argv[3] / "magisk"

if not magisk_apk:
    magisk_apk = "stable"
if magisk_apk == "stable" or magisk_apk == "beta" or magisk_apk == "canary" or magisk_apk == "debug":
    magisk_apk = json.loads(requests.get(
        f"https://github.com/topjohnwu/magisk-files/raw/master/{magisk_apk}.json").content)['magisk']['link']

out_file = download_dir / "magisk.zip"

arch = sys.argv[1]

abi_map = {"x64": ["x86_64", "x86"], "arm64": ["arm64-v8a", "armeabi-v7a"]}

if not os.path.isfile(out_file):
    urllib.request.urlretrieve(magisk_apk, out_file)


def extract_as(zip, name, as_name, dir):
    info = zip.getinfo(name)
    info.filename = as_name
    zip.extract(info, workdir / dir)


with zipfile.ZipFile(out_file) as zip:
    extract_as(
        zip, f"lib/{ abi_map[arch][0] }/libmagisk64.so", "magisk64", "magisk")
    extract_as(
        zip, f"lib/{ abi_map[arch][1] }/libmagisk32.so", "magisk32", "magisk")
    standalone_policy = False
    try:
        zip.getinfo(f"lib/{ abi_map[arch][0] }/libmagiskpolicy.so")
        standalone_policy = True
    except:
        pass
    extract_as(
        zip, f"lib/{ abi_map[arch][0] }/libmagiskinit.so", "magiskinit", "magisk")
    if standalone_policy:
        extract_as(
            zip, f"lib/{ abi_map[arch][0] }/libmagiskpolicy.so", "magiskpolicy", "magisk")
    else:
        extract_as(
            zip, f"lib/{ abi_map[arch][0] }/libmagiskinit.so", "magiskpolicy", "magisk")
    extract_as(
        zip, f"lib/{ abi_map[arch][0] }/libmagiskboot.so", "magiskboot", "magisk")
    extract_as(
        zip, f"lib/{ abi_map[arch][0] }/libbusybox.so", "busybox", "magisk")
    if standalone_policy:
        extract_as(
            zip, f"lib/{ abi_map['x64'][0] }/libmagiskpolicy.so", "magiskpolicy", ".")
    else:
        extract_as(
            zip, f"lib/{ abi_map['x64'][0] }/libmagiskinit.so", "magiskpolicy", ".")
    extract_as(zip, f"assets/boot_patch.sh", "boot_patch.sh", "magisk")
    extract_as(zip, f"assets/util_functions.sh",
               "util_functions.sh", "magisk")
