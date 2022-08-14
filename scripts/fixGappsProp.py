from __future__ import annotations
from io import TextIOWrapper
from os import system, path
from typing import OrderedDict
import sys
class Prop(OrderedDict):
    def __init__(self, file: TextIOWrapper) -> None:
        super().__init__()
        for i, line in enumerate(file.read().splitlines(False)):
            if '=' in line:
                k, v = line.split('=', 2)
                self[k] = v
            else:
                self[f".{i}"] = line

    def __str__(self) -> str:
        return '\n'.join([v if k.startswith('.') else f"{k}={v}" for k, v in self.items()])

    def __iadd__(self, other: str) -> Prop:
        self[f".{len(self)}"] = other
        return self


new_props = {
    ("product", "brand"): "google",
    ("product", "manufacturer"): "Google",
    ("build", "product"): "redfin",
    ("product", "name"): "redfin",
    ("product", "device"): "redfin",
    ("product", "model"): "Pixel 5",
    ("build", "flavor"): "redfin-user"
}


def description(sec: str, p: Prop) -> str:
    return f"{p[f'ro.{sec}.build.flavor']} {p[f'ro.{sec}.build.version.release_or_codename']} {p[f'ro.{sec}.build.id']} {p[f'ro.{sec}.build.version.incremental']} {p[f'ro.{sec}.build.tags']}"


def fingerprint(sec: str, p: Prop) -> str:
    return f"""{p[f"ro.product.{sec}.brand"]}/{p[f"ro.product.{sec}.name"]}/{p[f"ro.product.{sec}.device"]}:{p[f"ro.{sec}.build.version.release"]}/{p[f"ro.{sec}.build.id"]}/{p[f"ro.{sec}.build.version.incremental"]}:{p[f"ro.{sec}.build.type"]}/{p[f"ro.{sec}.build.tags"]}"""


def fix_prop(sec, prop):
    if not path.exists(prop):
        return

    print(f"fixing {prop}", flush=True)
    with open(prop, 'r') as f:
        p = Prop(f)

    p += "# extra prop added by MagiskOnWSA"

    for k, v in new_props.items():
        p[f"ro.{k[0]}.{k[1]}"] = v

        if k[0] == "build":
            p[f"ro.{sec}.{k[0]}.{k[1]}"] = v
        elif k[0] == "product":
            p[f"ro.{k[0]}.{sec}.{k[1]}"] = v

    p["ro.build.description"] = description(sec, p)
    p[f"ro.build.fingerprint"] = fingerprint(sec, p)
    p[f"ro.{sec}.build.description"] = description(sec, p)
    p[f"ro.{sec}.build.fingerprint"] = fingerprint(sec, p)
    p[f"ro.bootimage.build.fingerprint"] = fingerprint(sec, p)

    with open(prop, 'w') as f:
        f.write(str(p))


sys_path = sys.argv[1]
for sec, prop in {"system": sys_path+"/system/build.prop", "product": sys_path+"/product/build.prop", "system_ext": sys_path+"/system_ext/build.prop", "vendor": sys_path+"/vendor/build.prop", "odm": sys_path+"/vendor/odm/etc/build.prop"}.items():
    fix_prop(sec, prop)
