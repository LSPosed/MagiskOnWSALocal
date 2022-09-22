#!/bin/bash
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

# DEBUG=--debug
# CUSTOM_MAGISK=--magisk-custom

if [ ! "$BASH_VERSION" ]; then
    echo "Please do not use sh to run this script, just execute it directly" 1>&2
    exit 1
fi
cd "$(dirname "$0")" || exit 1

abort() {
    echo "Dependencies: an error has occurred, exit"
    exit 1
}

echo "Checking and ensuring dependencies"
check_dependencies() {
    command -v whiptail >/dev/null 2>&1 || NEED_INSTALL+=("whiptail")
    command -v seinfo >/dev/null 2>&1 || NEED_INSTALL+=("setools")
    command -v lzip >/dev/null 2>&1 || NEED_INSTALL+=("lzip")
    command -v wine64 >/dev/null 2>&1 || NEED_INSTALL+=("wine")
    command -v winetricks >/dev/null 2>&1 || NEED_INSTALL+=("winetricks")
    command -v patchelf >/dev/null 2>&1 || NEED_INSTALL+=("patchelf")
    command -v resize2fs >/dev/null 2>&1 || NEED_INSTALL+=("e2fsprogs")
    command -v pip >/dev/null 2>&1 || NEED_INSTALL+=("python3-pip")
    command -v aria2c >/dev/null 2>&1 || NEED_INSTALL+=("aria2")
    command -v 7z > /dev/null 2>&1 || NEED_INSTALL+=("p7zip-full")
    command -v setfattr > /dev/null 2>&1 || NEED_INSTALL+=("attr")
}
check_dependencies
declare -A os_pm_install;
# os_pm_install["/etc/redhat-release"]=yum
# os_pm_install["/etc/arch-release"]=pacman
# os_pm_install["/etc/gentoo-release"]=emerge
# os_pm_install["/etc/SuSE-release"]=zypp
os_pm_install["/etc/debian_version"]=apt-get
# os_pm_install["/etc/alpine-release"]=apk

declare -A PM_UPDATE_MAP;
PM_UPDATE_MAP["yum"]="check-update"
PM_UPDATE_MAP["pacman"]="-Syu --noconfirm"
PM_UPDATE_MAP["emerge"]="-auDN @world"
PM_UPDATE_MAP["zypp"]="update -y"
PM_UPDATE_MAP["apt-get"]="update"
PM_UPDATE_MAP["apk"]="update"

declare -A PM_INSTALL_MAP;
PM_INSTALL_MAP["yum"]="install -y"
PM_INSTALL_MAP["pacman"]="-S --noconfirm --needed"
PM_INSTALL_MAP["emerge"]="-a"
PM_INSTALL_MAP["zypp"]="install -y"
PM_INSTALL_MAP["apt-get"]="install -y"
PM_INSTALL_MAP["apk"]="add"

check_package_manager() {
    for f in "${!os_pm_install[@]}"; do
        if [[ -f $f ]]; then
            PM="${os_pm_install[$f]}"
            readarray -td ' ' UPDATE_OPTION <<<"${PM_UPDATE_MAP[$PM]} "; unset 'UPDATE_OPTION[-1]';
            readarray -td ' ' INSTALL_OPTION <<<"${PM_INSTALL_MAP[$PM]} "; unset 'INSTALL_OPTION[-1]';
            break
        fi
    done
}

check_package_manager
if [ -n "${NEED_INSTALL[*]}" ]; then
    if [ -z "$PM" ]; then
        echo "Unable to determine package manager: unknown distribution"
        abort
    else
        if ! (sudo "$PM" "${UPDATE_OPTION[@]}" && sudo "$PM" "${INSTALL_OPTION[@]}" "${NEED_INSTALL[@]}") then abort; fi
    fi
fi
pip list --disable-pip-version-check | grep -E "^requests " >/dev/null 2>&1 || python3 -m pip install requests

winetricks list-installed | grep -E "^msxml6" >/dev/null 2>&1 || {
    cp -r ../wine/.cache/* ~/.cache
    winetricks msxml6 || abort
}
