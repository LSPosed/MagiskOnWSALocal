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
# Copyright (C) 2023 LSPosed Contributors
#

if [ ! "$BASH_VERSION" ]; then
    echo "Please do not use sh to run this script, just execute it directly" 1>&2
    exit 1
fi
cd "$(dirname "$0")" || exit 1
SCRIPT_DIR="$(pwd)"
SUDO="$(which sudo 2>/dev/null)"
abort() {
    [ "$1" ] && echo "ERROR: $1"
    echo "Dependencies: an error has occurred, exit"
    exit 1
}
require_su() {
    if test "$(id -u)" != "0"; then
        if [ -z "$SUDO" ] && [ "$($SUDO id -u)" != "0" ]; then
            echo "ROOT/SUDO is required to run this script"
            abort
        fi
    fi
}
ARGUMENT_LIST=(
    "force-upgrade-erofs-utils"
)
opts=$(
    getopt \
        --longoptions "$(printf "%s," "${ARGUMENT_LIST[@]}")" \
        --name "$(basename "$0")" \
        --options "" \
        -- "$@"
) || exit_with_message "Failed to parse options, please check your input"
eval set --"$opts"
while [[ $# -gt 0 ]]; do
    case "$1" in
    --force-upgrade-erofs-utils)
        FORCE_UPGRADE_EROFS_UTILS=1
        shift
        ;;
    --)
        shift
        break
        ;;
    esac
done
echo "Checking and ensuring dependencies"
check_dependencies() {
    command -v whiptail >/dev/null 2>&1 || command -v dialog >/dev/null 2>&1 || NEED_INSTALL+=("whiptail")
    command -v lzip >/dev/null 2>&1 || NEED_INSTALL+=("lzip")
    command -v patchelf >/dev/null 2>&1 || NEED_INSTALL+=("patchelf")
    command -v resize2fs >/dev/null 2>&1 || NEED_INSTALL+=("e2fsprogs")
    command -v pip >/dev/null 2>&1 || NEED_INSTALL+=("python3-pip")
    command -v aria2c >/dev/null 2>&1 || NEED_INSTALL+=("aria2")
    command -v 7z >/dev/null 2>&1 || NEED_INSTALL+=("p7zip-full")
    command -v setfattr >/dev/null 2>&1 || NEED_INSTALL+=("attr")
    command -v unzip >/dev/null 2>&1 || NEED_INSTALL+=("unzip")
    command -v qemu-img >/dev/null 2>&1 || NEED_INSTALL+=("qemu-utils")
    command -v sudo >/dev/null 2>&1 || NEED_INSTALL+=("sudo")
    command -v automake >/dev/null 2>&1 || NEED_INSTALL+=("automake")
    command -v libtoolize >/dev/null 2>&1 || NEED_INSTALL+=("libtool")
    command -v m4 >/dev/null 2>&1 || NEED_INSTALL+=("m4")
    command -v pkg-config >/dev/null 2>&1 || NEED_INSTALL+=("pkg-config")
    [ -d /usr/include/uuid ] || NEED_INSTALL+=("uuid-dev")
    [ -d /usr/include/fuse3 ] || NEED_INSTALL+=("libfuse3-dev")
    [ -f /usr/include/lz4.h ] || NEED_INSTALL+=("liblz4-dev")
    command -v erofsfuse >/dev/null 2>&1 && [ ! "$FORCE_UPGRADE_EROFS_UTILS" ] || MAKE_INSTALL+=("erofs-utils")
}
check_dependencies
osrel=$(sed -n '/^ID_LIKE=/s/^.*=//p' /etc/os-release)
declare -A os_pm_install
# os_pm_install["/etc/redhat-release"]=yum
# os_pm_install["/etc/arch-release"]=pacman
# os_pm_install["/etc/gentoo-release"]=emerge
os_pm_install["/etc/SuSE-release"]=zypper
os_pm_install["/etc/debian_version"]=apt-get
# os_pm_install["/etc/alpine-release"]=apk

declare -A PM_UPDATE_MAP
PM_UPDATE_MAP["yum"]="check-update"
PM_UPDATE_MAP["pacman"]="-Syu --noconfirm"
PM_UPDATE_MAP["emerge"]="-auDN @world"
PM_UPDATE_MAP["zypper"]="ref"
PM_UPDATE_MAP["apt-get"]="update"
PM_UPDATE_MAP["apk"]="update"

declare -A PM_INSTALL_MAP
PM_INSTALL_MAP["yum"]="install -y"
PM_INSTALL_MAP["pacman"]="-S --noconfirm --needed"
PM_INSTALL_MAP["emerge"]="-a"
PM_INSTALL_MAP["zypper"]="in -y"
PM_INSTALL_MAP["apt-get"]="install -y"
PM_INSTALL_MAP["apk"]="add"

declare -A PM_UPGRADE_MAP
PM_UPGRADE_MAP["apt-get"]="upgrade -y"
PM_UPGRADE_MAP["zypper"]="up -y"

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
        readarray -td ' ' UPDATE_OPTION <<<"${PM_UPDATE_MAP[$PM]} "
        unset 'UPDATE_OPTION[-1]'
        readarray -td ' ' INSTALL_OPTION <<<"${PM_INSTALL_MAP[$PM]} "
        unset 'INSTALL_OPTION[-1]'
        readarray -td ' ' UPGRADE_OPTION <<<"${PM_UPGRADE_MAP[$PM]} "
        unset 'UPGRADE_OPTION[-1]'
    fi
}

check_package_manager
require_su
if [ -z "$PM" ]; then
    echo "Unable to determine package manager: Unsupported distros"
    abort
else
    if ! ($SUDO "$PM" "${UPDATE_OPTION[@]}" && $SUDO "$PM" "${UPGRADE_OPTION[@]}" ca-certificates); then abort; fi
fi

if [ -n "${NEED_INSTALL[*]}" ]; then
    if [ "$PM" = "zypper" ]; then
        NEED_INSTALL_FIX=${NEED_INSTALL[*]}
        {
            NEED_INSTALL_FIX=${NEED_INSTALL_FIX//setools/setools-console} 2>&1
            NEED_INSTALL_FIX=${NEED_INSTALL_FIX//whiptail/dialog} 2>&1
            NEED_INSTALL_FIX=${NEED_INSTALL_FIX//qemu-utils/qemu-tools} 2>&1
            NEED_INSTALL_FIX=${NEED_INSTALL_FIX//python3-venv/python3-venvctrl} 2>&1
        } >>/dev/null

        readarray -td ' ' NEED_INSTALL <<<"$NEED_INSTALL_FIX "
        unset 'NEED_INSTALL[-1]'
    elif [ "$PM" = "apk" ]; then
        NEED_INSTALL_FIX=${NEED_INSTALL[*]}
        readarray -td ' ' NEED_INSTALL <<<"${NEED_INSTALL_FIX//p7zip-full/p7zip} "
        unset 'NEED_INSTALL[-1]'
    fi
    if ! ($SUDO "$PM" "${INSTALL_OPTION[@]}" "${NEED_INSTALL[@]}"); then abort; fi

fi

if [ -n "${MAKE_INSTALL[*]}" ]; then
    WORK_DIR=$(mktemp -d -t wsa-pkg-XXXXXXXXXX_) || exit 1
    trap 'sudo rm -rf -- "${WORK_DIR:?}"' EXIT
    for package in "${MAKE_INSTALL[@]}"; do
        case "$package" in
        "erofs-utils")
            wget -O "$WORK_DIR/erofs-utils-libfuse3.zip" "https://github.com/LSPosed/erofs-utils/archive/refs/heads/libfuse3.zip" || abort "Failed to download $package"
            unzip "$WORK_DIR/erofs-utils-libfuse3.zip" -d "$WORK_DIR"
            cd "$WORK_DIR/erofs-utils-libfuse3" || abort "Failed to enter $WORK_DIR/erofs-utils-libfuse3"
            autoupdate
            ./autogen.sh || abort "Failed to autogen configure"
            ./configure --enable-lzma --enable-fuse --with-selinux=yes || abort "Failed to configure make"
            sudo make install || abort "Failed to install $package"
            cd "$SCRIPT_DIR" || abort "Failed to enter $SCRIPT_DIR"
            ;;
        esac
    done
fi
python_version=$(python3 -c 'import sys;print("{0}{1}".format(*(sys.version_info[:2])))')
if [ "$python_version" -ge 311 ]; then
    python3 -c "import venv" >/dev/null 2>&1 || if ! ($SUDO "$PM" "${INSTALL_OPTION[@]}" "python3-venv"); then abort; fi
    PYTHON_VENV_DIR="$(dirname "$PWD")/python3-env"
    [ -f "$PYTHON_VENV_DIR/bin/activate" ] || {
        echo "Creating python3 virtual env"
        python3 -m venv "$PYTHON_VENV_DIR" || abort "Failed to create python3 virtual env"
    }
    # shellcheck disable=SC1091
    source "$PYTHON_VENV_DIR"/bin/activate || abort "Failed to activate python3 virtual env"
    python3 -c "import pkg_resources; pkg_resources.require(open('requirements.txt',mode='r'))" &>/dev/null || {
        echo "Installing Python3 dependencies"
        python3 -m pip install -r requirements.txt || abort "Failed to install python3 dependencies"
    }
    deactivate
else
    python3 -m pip install -r requirements.txt -q || abort "Failed to install python3 dependencies"
fi
