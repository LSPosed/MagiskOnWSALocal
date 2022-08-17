#!/usr/bin/python

import sys

import requests
from xml.dom import minidom
import html
import warnings
import re
import zipfile
import os
import urllib.request
from pathlib import Path

warnings.filterwarnings("ignore")

arch = sys.argv[1]
release_type_map = {"retail": "Retail", "release preview": "RP",
                    "insider slow": "WIS", "insider fast": "WIF"}
release_type = release_type_map[sys.argv[2]] if sys.argv[2] != "" else "Retail"

cat_id = '858014f3-3934-4abe-8078-4aa193e74ca8'

with open(Path.cwd().parent / ("xml/GetCookie.xml"), "r") as f:
    cookie_content = f.read()

out = requests.post(
    'https://fe3.delivery.mp.microsoft.com/ClientWebService/client.asmx',
    data=cookie_content,
    headers={'Content-Type': 'application/soap+xml; charset=utf-8'},
    verify=False
)
doc = minidom.parseString(out.text)
cookie = doc.getElementsByTagName('EncryptedData')[0].firstChild.nodeValue

with open(Path.cwd().parent / "xml/WUIDRequest.xml", "r") as f:
    cat_id_content = f.read().format(cookie, cat_id, release_type)

out = requests.post(
    'https://fe3.delivery.mp.microsoft.com/ClientWebService/client.asmx',
    data=cat_id_content,
    headers={'Content-Type': 'application/soap+xml; charset=utf-8'},
    verify=False
)

doc = minidom.parseString(html.unescape(out.text))

filenames = {}
for node in doc.getElementsByTagName('Files'):
    filenames[node.parentNode.parentNode.getElementsByTagName(
        'ID')[0].firstChild.nodeValue] = f"{node.firstChild.attributes['InstallerSpecificIdentifier'].value}_{node.firstChild.attributes['FileName'].value}"
    pass

identities = []
for node in doc.getElementsByTagName('SecuredFragment'):
    filename = filenames[node.parentNode.parentNode.parentNode.getElementsByTagName('ID')[
        0].firstChild.nodeValue]
    update_identity = node.parentNode.parentNode.firstChild
    identities += [(update_identity.attributes['UpdateID'].value,
                    update_identity.attributes['RevisionNumber'].value, filename)]

with open(Path.cwd().parent / "xml/FE3FileUrl.xml", "r") as f:
    file_content = f.read()
if not os.path.exists(Path.cwd().parent / "download"):
    os.makedirs(Path.cwd().parent / "download")
for i, v, f in identities:
    if re.match(f"Microsoft\.UI\.Xaml\..*_{arch}_.*\.appx", f):
        out_file = Path.cwd().parent / "download/xaml.appx"
    elif re.match(f"Microsoft\.VCLibs\..*_{arch}_.*\.appx", f):
        out_file = Path.cwd().parent / "download/vclibs.appx"
    elif re.match(f"MicrosoftCorporationII\.WindowsSubsystemForAndroid_.*\.msixbundle", f):
        out_file = Path.cwd().parent / "download/wsa.zip"
    else:
        continue
    out = requests.post(
        'https://fe3.delivery.mp.microsoft.com/ClientWebService/client.asmx/secured',
        data=file_content.format(i, v, release_type),
        headers={'Content-Type': 'application/soap+xml; charset=utf-8'},
        verify=False
    )
    doc = minidom.parseString(out.text)
    for l in doc.getElementsByTagName("FileLocation"):
        url = l.getElementsByTagName("Url")[0].firstChild.nodeValue
        if len(url) != 99:
            if not os.path.isfile(out_file):
                print(f"downloading link: {url} to {out_file}", flush=True)
                urllib.request.urlretrieve(url, out_file)
