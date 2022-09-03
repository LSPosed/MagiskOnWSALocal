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
SUDO="$(which sudo 2>/dev/null)"
abort() {
    echo "Dependencies: an error has occurred, exit"
    exit 1
}
require_su() {
    if test "$(whoami)" != "root"; then
        if [ -z "$SUDO" ] && [ "$($SUDO whoami)" != "root" ]; then
            echo "ROOT/SUDO is required to run this script"
            abort
        fi
    fi
}
echo "Checking and ensuring dependencies"
check_dependencies() {
    command -v whiptail >/dev/null 2>&1 || command -v dialog >/dev/null 2>&1 || NEED_INSTALL+=("whiptail")
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
osrel=$(sed -n '/^ID_LIKE=/s/^.*=//p' /etc/os-release);
declare -A os_pm_install;
# os_pm_install["/etc/redhat-release"]=yum
# os_pm_install["/etc/arch-release"]=pacman
# os_pm_install["/etc/gentoo-release"]=emerge
os_pm_install["/etc/SuSE-release"]=zypper
os_pm_install["/etc/debian_version"]=apt-get
# os_pm_install["/etc/alpine-release"]=apk

declare -A PM_UPDATE_MAP;
PM_UPDATE_MAP["yum"]="check-update"
PM_UPDATE_MAP["pacman"]="-Syu --noconfirm"
PM_UPDATE_MAP["emerge"]="-auDN @world"
PM_UPDATE_MAP["zypper"]="ref"
PM_UPDATE_MAP["apt-get"]="update"
PM_UPDATE_MAP["apk"]="update"

declare -A PM_INSTALL_MAP;
PM_INSTALL_MAP["yum"]="install -y"
PM_INSTALL_MAP["pacman"]="-S --noconfirm --needed"
PM_INSTALL_MAP["emerge"]="-a"
PM_INSTALL_MAP["zypper"]="in -y"
PM_INSTALL_MAP["apt-get"]="install -y"
PM_INSTALL_MAP["apk"]="add"

check_package_manager() {
    for f in "${!os_pm_install[@]}"; do
        if [[ -f $f ]]; then
            PM="${os_pm_install[$f]}"
            break
        fi
    done
    if [[ "$osrel" = *"suse"* ]]; then
        PM="zypper"
    fi
    if [ -n "$PM" ]; then
        readarray -td ' ' UPDATE_OPTION <<<"${PM_UPDATE_MAP[$PM]} "; unset 'UPDATE_OPTION[-1]';
        readarray -td ' ' INSTALL_OPTION <<<"${PM_INSTALL_MAP[$PM]} "; unset 'INSTALL_OPTION[-1]';
    fi
}

check_package_manager
if [ -n "${NEED_INSTALL[*]}" ]; then
    if [ -z "$PM" ]; then
        echo "Unable to determine package manager: Unsupported distros"
        abort
    else
        if [ "$PM" = "zypper" ]; then
            NEED_INSTALL_FIX=${NEED_INSTALL[*]}
            NEED_INSTALL_FIX=${NEED_INSTALL_FIX//setools/setools-console} >> /dev/null 2>&1
            NEED_INSTALL_FIX=${NEED_INSTALL_FIX//whiptail/dialog} >> /dev/null 2>&1
            readarray -td ' ' NEED_INSTALL <<<"$NEED_INSTALL_FIX "; unset 'NEED_INSTALL[-1]';
        elif [ "$PM" = "apk" ]; then
            NEED_INSTALL_FIX=${NEED_INSTALL[*]}
            readarray -td ' ' NEED_INSTALL <<<"${NEED_INSTALL_FIX//p7zip-full/p7zip} "; unset 'NEED_INSTALL[-1]';
        fi
        require_su
        if ! ($SUDO "$PM" "${UPDATE_OPTION[@]}" && $SUDO "$PM" "${INSTALL_OPTION[@]}" "${NEED_INSTALL[@]}") then abort; fi
    fi
fi
pip list --disable-pip-version-check | grep -E "^requests " >/dev/null 2>&1 || python3 -m pip install requests

winetricks list-installed | grep -E "^msxml6" >/dev/null 2>&1 || {
    cp -r ../wine/.cache/* ~/.cache
    winetricks msxml6 || abort
}
WHIPTAIL=$(command -v whiptail 2>/dev/null)
DIALOG=$(command -v dialog 2>/dev/null)
DIALOG=${WHIPTAIL:-$DIALOG}
function Radiolist {
    declare -A o="$1"
    shift
    if ! $DIALOG --nocancel --radiolist "${o[title]}" 0 0 0 "$@" 3>&1 1>&2 2>&3; then
        echo "${o[default]}"
    fi
}

function YesNoBox {
    declare -A o="$1"
    shift
    $DIALOG --title "${o[title]}" --yesno "${o[text]}" 0 0
}

ARCH=$(
    Radiolist '([title]="Build arch"
                [default]="x64")' \
        \
        'x64' "X86_64" 'on' \
        'arm64' "AArch64" 'off'
)

RELEASE_TYPE=$(
    Radiolist '([title]="WSA release type"
                [default]="retail")' \
        \
        'retail' "Stable Channel" 'on' \
        'release preview' "Release Preview Channel" 'off' \
        'insider slow' "Beta Channel" 'off' \
        'insider fast' "Dev Channel" 'off'
)

if [ -z "${CUSTOM_MAGISK+x}" ]; then
    MAGISK_VER=$(
        Radiolist '([title]="Magisk version"
                        [default]="stable")' \
            \
            'stable' "Stable Channel" 'on' \
            'beta' "Beta Channel" 'off' \
            'canary' "Canary Channel" 'off' \
            'debug' "Canary Channel Debug Build" 'off'
    )
else
    MAGISK_VER=debug
fi

if (YesNoBox '([title]="Install GApps" [text]="Do you want to install GApps?")'); then
    GAPPS_BRAND=$(
        Radiolist '([title]="Which GApps do you want to install?"
                 [default]="MindTheGapps")' \
            \
            'OpenGApps' "" 'off' \
            'MindTheGapps' "" 'on'
    )
else
    GAPPS_BRAND="none"
fi
if [ $GAPPS_BRAND = "OpenGApps" ]; then
    GAPPS_VARIANT=$(
        Radiolist '([title]="Variants of GApps"
                     [default]="pico")' \
            \
            'super' "" 'off' \
            'stock' "" 'off' \
            'full' "" 'off' \
            'mini' "" 'off' \
            'micro' "" 'off' \
            'nano' "" 'off' \
            'pico' "" 'on' \
            'tvstock' "" 'off' \
            'tvmini' "" 'off'
    )
else
    GAPPS_VARIANT="pico"
fi

if (YesNoBox '([title]="Remove Amazon Appstore" [text]="Do you want to keep Amazon Appstore?")'); then
    REMOVE_AMAZON=""
else
    REMOVE_AMAZON="--remove-amazon"
fi

ROOT_SOL=$(
    Radiolist '([title]="Root solution"
                     [default]="magisk")' \
        \
        'magisk' "" 'on' \
        'none' "" 'off'
)

if (YesNoBox '([title]="Compress output" [text]="Do you want to compress the output?")'); then
    COMPRESS_OUTPUT="--compress"
else
    COMPRESS_OUTPUT=""
fi

# if ! (YesNoBox '([title]="Off line mode" [text]="Do you want to enable off line mode?")'); then
#     OFFLINE="--offline"
# else
#     OFFLINE=""
# fi
# OFFLINE="--offline"
clear
declare -A RELEASE_TYPE_MAP=(["retail"]="retail" ["release preview"]="RP" ["insider slow"]="WIS" ["insider fast"]="WIF")
COMMAND_LINE=(--arch "$ARCH" --release-type "${RELEASE_TYPE_MAP[$RELEASE_TYPE]}" --magisk-ver "$MAGISK_VER" --gapps-brand "$GAPPS_BRAND" --gapps-variant "$GAPPS_VARIANT" "$REMOVE_AMAZON" --root-sol "$ROOT_SOL" "$COMPRESS_OUTPUT" "$OFFLINE" "$DEBUG" "$CUSTOM_MAGISK")
echo "COMMAND_LINE=${COMMAND_LINE[*]}"
./build.sh "${COMMAND_LINE[@]}"
