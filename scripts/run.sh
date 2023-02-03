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

# DEBUG=--debug
# CUSTOM_MAGISK=--magisk-custom
if [ ! "$BASH_VERSION" ]; then
    echo "Please do not use sh to run this script, just execute it directly" 1>&2
    exit 1
fi
cd "$(dirname "$0")" || exit 1

./install_deps.sh

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
            'OpenGApps' "This flavor may cause startup failure" 'off' \
            'MindTheGapps' "Recommend" 'on'
    )
else
    GAPPS_BRAND="none"
fi
if [ "$GAPPS_BRAND" = "OpenGApps" ]; then
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
if [ "$COMPRESS_OUTPUT" = "--compress" ]; then
    COMPRESS_FORMAT=$(
        Radiolist '([title]="Compress format"
                        [default]="7z")' \
            \
            'zip' "Zip" 'off' \
            '7z' "7-Zip" 'on' \
            'xz' "tar.xz" 'off'
        )
fi
# if (YesNoBox '([title]="Off line mode" [text]="Do you want to enable off line mode?")'); then
#     OFFLINE="--offline"
# else
#     OFFLINE=""
# fi
# OFFLINE="--offline"
clear
declare -A RELEASE_TYPE_MAP=(["retail"]="retail" ["release preview"]="RP" ["insider slow"]="WIS" ["insider fast"]="WIF")
COMMAND_LINE=(--arch "$ARCH" --release-type "${RELEASE_TYPE_MAP[$RELEASE_TYPE]}" --magisk-ver "$MAGISK_VER" --gapps-brand "$GAPPS_BRAND" --gapps-variant "$GAPPS_VARIANT" "$REMOVE_AMAZON" --root-sol "$ROOT_SOL" "$COMPRESS_OUTPUT" "$OFFLINE" "$DEBUG" "$CUSTOM_MAGISK" --compress-format "$COMPRESS_FORMAT")
echo "COMMAND_LINE=${COMMAND_LINE[*]}"
./build.sh "${COMMAND_LINE[@]}"
