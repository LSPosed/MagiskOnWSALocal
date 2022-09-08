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

DOWNLOAD_DIR=../download

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

function Radiolist {
    declare -A o="$1"
    shift
    if ! whiptail --nocancel --radiolist "${o[title]}" 0 0 0 "$@" 3>&1 1>&2 2>&3; then
        echo "${o[default]}"
    fi
}

function YesNoBox {
    declare -A o="$1"
    shift
    whiptail --title "${o[title]}" --yesno "${o[text]}" 0 0
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
    if [ -f "$DOWNLOAD_DIR"/MindTheGapps-"$ARCH".zip ]; then
        GAPPS_BRAND=$(
            Radiolist '([title]="Which GApps do you want to install?"
                     [default]="OpenGApps")' \
                \
                'OpenGApps' "" 'on' \
                'MindTheGapps' "" 'off'
        )
    else
        GAPPS_BRAND="OpenGApps"
    fi
else
    GAPPS_BRAND="none"
fi
if [ $GAPPS_BRAND = "OpenGApps" ]; then
    # TODO: Keep it pico since other variants of opengapps are unable to boot successfully
    if [ "$DEBUG" = "1" ]; then
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
        GAPPS_VARIANT=pico
    fi
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
