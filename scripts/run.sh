#!/bin/bash

WORK_DIR=$(mktemp -d -t wsa-build-XXXXXXXXXX_)
DOWNLOAD_DIR=../download
OUTPUT_DIR=../output
MOUNT_DIR="$WORK_DIR"/system
cd "$(dirname "$0")" || exit 1

abort() {
    echo "An error occurs, exit"
    if [ -d "$WORK_DIR" ]; then
        echo "Cleanup Work Directory"
        if [ -d "$MOUNT_DIR" ]; then
            if [ -d "$MOUNT_DIR/vendor" ]; then
                sudo umount "$MOUNT_DIR"/vendor
            fi
            if [ -d "$MOUNT_DIR/product" ]; then
                sudo umount "$MOUNT_DIR"/product
            fi
            if [ -d "$MOUNT_DIR/system_ext" ]; then
                sudo umount "$MOUNT_DIR"/system_ext
            fi
            sudo umount "$MOUNT_DIR"
        fi
        sudo rm -rf "$WORK_DIR"
    fi
    if [ -d "$DOWNLOAD_DIR" ]; then
        echo "Cleanup Download Directory"
        sudo rm -rf "$DOWNLOAD_DIR"
    fi
    if [ -d "$OUTPUT_DIR" ]; then
        echo "Cleanup Output Directory"
        sudo rm -rf "$OUTPUT_DIR"
    fi
    exit 1
}

if [ ! "$BASH_VERSION" ] ; then
    echo "Please do not use sh to run this script, just execute it directly" 1>&2
    abort
fi

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

function Gen_Rand_Str {
    tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w "$1" | head -n 1
}

echo "Dependencies"
sudo apt update && sudo apt -y install setools lzip wine winetricks patchelf whiptail e2fsprogs python3-pip
sudo python3 -m pip install requests
cp -r ../wine/.cache/* ~/.cache
winetricks msxml6 || abort

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

MAGISK_VER=$(
    Radiolist '([title]="Magisk version"
                     [default]="stable")' \
        \
        'stable' "Stable Channel" 'on' \
        'beta' "Beta Channel" 'off' \
        'canary' "Canary Channel" 'off' \
        'debug' "Canary Channel Debug Build" 'off'
)

if (YesNoBox '([title]="Install Gapps" [text]="Do you want to install gapps?")'); then
    if [ -f "$DOWNLOAD_DIR"/MindTheGapps/MindTheGapps_"$ARCH".zip ]; then
        GAPPS_BRAND=$(
            Radiolist '([title]="Which gapps do you want to install?"
                     [default]="OpenGapps")' \
                \
                'OpenGapps' "" 'on' \
                'MindTheGapps' "" 'off'
        )
    else
        GAPPS_BRAND="OpenGapps"
    fi
else
    GAPPS_VARIANT="none"
fi
if [ $GAPPS_BRAND = "OpenGapps" ]; then
    GAPPS_VARIANT=$(
        Radiolist '([title]="Variants of gapps"
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
    GAPPS_VARIANT=$GAPPS_BRAND
fi

if (YesNoBox '([title]="Remove Amazon AppStore" [text]="Do you want to keep amazon appStore?")'); then
    REMOVE_AMAZON="keep"
else
    REMOVE_AMAZON="remove"
fi

ROOT_SOL=$(
    Radiolist '([title]="Root solution"
                     [default]="magisk")' \
        \
        'magisk' "" 'on' \
        'none' "" 'off'
)

clear
echo -e "ARCH=$ARCH\nRELEASE_TYPE=$RELEASE_TYPE\nMAGISK_VER=$MAGISK_VER\nGAPPS_VARIANT=$GAPPS_VARIANT\nREMOVE_AMAZON=$REMOVE_AMAZON\nROOT_SOL=$ROOT_SOL\n"

echo "Download WSA"
python3 downloadWSA.py "$ARCH" "$RELEASE_TYPE" || abort
echo -e "Download done\n"

echo "Extract WSA"
WSA_WORK_ENV="$WORK_DIR"/ENV
if [ -f "$WSA_WORK_ENV" ]; then rm -f "$WSA_WORK_ENV"; fi
export WSA_WORK_ENV
python3 extractWSA.py "$ARCH" "$WORK_DIR" || abort
echo -e "Extract done\n"

echo "Download Magisk"
python3 downloadMagisk.py "$ARCH" "$MAGISK_VER" "$WORK_DIR" || abort
echo -e "done\n"

if [ $GAPPS_VARIANT != 'none' ] && [ $GAPPS_VARIANT != '' ]; then
    if [ $GAPPS_BRAND = "OpenGapps" ]; then
        echo "Download OpenGApps"
        python3 downloadGapps.py "$ARCH" "$MAGISK_VER" || abort
        echo -e "Download done\n"
    fi
    echo "Extract GApps"
    mkdir -p "$WORK_DIR"/gapps || abort
    if [ $GAPPS_BRAND = "OpenGapps" ]; then
        unzip -p "$DOWNLOAD_DIR"/gapps.zip {Core,GApps}/'*.lz' | tar --lzip -C "$WORK_DIR"/gapps -xf - -i --strip-components=2 --exclude='setupwizardtablet-x86_64' --exclude='packageinstallergoogle-all' --exclude='speech-common' --exclude='markup-lib-arm' --exclude='markup-lib-arm64' --exclude='markup-all' --exclude='setupwizarddefault-x86_64' --exclude='pixellauncher-all' --exclude='pixellauncher-common' || abort
    else
        unzip "$DOWNLOAD_DIR"/MindTheGapps/MindTheGapps_"$ARCH".zip "system/*" -x "system/addon.d/*" "system/system_ext/priv-app/SetupWizard/*" -d "$WORK_DIR"/gapps || abort
        mv "$WORK_DIR"/gapps/system/* "$WORK_DIR"/gapps || abort
        sudo rm -rf "$WORK_DIR"/gapps/system || abort
    fi
    echo -e "Extract done\n"
fi

echo "Expand images"

e2fsck -yf "$WORK_DIR"/wsa/"$ARCH"/system_ext.img || abort
SYSTEM_EXT_SIZE=$(($(du -bsB512 "$WORK_DIR"/wsa/"$ARCH"/system_ext.img | cut -f1) + 20000))
if [ -d "$WORK_DIR"/gapps/system_ext ]; then
    SYSTEM_EXT_SIZE=$(( SYSTEM_EXT_SIZE + $(du -bsB512 "$WORK_DIR"/gapps/system_ext | cut -f1) ))
fi
resize2fs "$WORK_DIR"/wsa/"$ARCH"/system_ext.img "$SYSTEM_EXT_SIZE"s || abort

e2fsck -yf "$WORK_DIR"/wsa/"$ARCH"/product.img || abort
PRODUCT_SIZE=$(($(du -bsB512 "$WORK_DIR"/wsa/"$ARCH"/product.img | cut -f1) + 20000))
if [ -d "$WORK_DIR"/gapps/product ]; then
    PRODUCT_SIZE=$(( PRODUCT_SIZE + $(du -bsB512 "$WORK_DIR"/gapps/product | cut -f1) ))
fi
resize2fs "$WORK_DIR"/wsa/"$ARCH"/product.img "$PRODUCT_SIZE"s || abort

e2fsck -yf "$WORK_DIR"/wsa/"$ARCH"/system.img || abort
SYSTEM_SIZE=$(($(du -bsB512 "$WORK_DIR"/wsa/"$ARCH"/system.img | cut -f1) + 20000))
if [ -d "$WORK_DIR"/gapps ]; then
    SYSTEM_SIZE=$(( SYSTEM_SIZE + $(du -bsB512 "$WORK_DIR"/gapps | cut -f1) - $(du -bsB512 "$WORK_DIR"/gapps/product | cut -f1) ))
    if [ -d "$WORK_DIR"/gapps/system_ext ]; then
        SYSTEM_SIZE=$(( SYSTEM_SIZE - $(du -bsB512 "$WORK_DIR"/gapps/system_ext | cut -f1) ))
    fi
fi
if [ -d "$WORK_DIR"/magisk ]; then
    SYSTEM_SIZE=$(( SYSTEM_SIZE + $(du -bsB512 "$WORK_DIR"/magisk/magisk | cut -f1) ))
fi
if [ -f "$DOWNLOAD_DIR"/magisk.zip ]; then
    SYSTEM_SIZE=$(( SYSTEM_SIZE + $(du -bsB512 "$DOWNLOAD_DIR"/magisk.zip | cut -f1) ))
fi
resize2fs "$WORK_DIR"/wsa/"$ARCH"/system.img "$SYSTEM_SIZE"s || abort

e2fsck -yf "$WORK_DIR"/wsa/"$ARCH"/vendor.img || abort
VENDOR_SIZE=$(($(du -bsB512 "$WORK_DIR"/wsa/"$ARCH"/vendor.img | cut -f1) + 20000))
resize2fs "$WORK_DIR"/wsa/"$ARCH"/vendor.img "$VENDOR_SIZE"s || abort
echo -e "Expand images done\n"

echo "Mount images"
sudo mkdir "$MOUNT_DIR" || abort
sudo mount -o loop "$WORK_DIR"/wsa/"$ARCH"/system.img "$MOUNT_DIR" || abort
sudo mount -o loop "$WORK_DIR"/wsa/"$ARCH"/vendor.img "$MOUNT_DIR"/vendor || abort
sudo mount -o loop "$WORK_DIR"/wsa/"$ARCH"/product.img "$MOUNT_DIR"/product || abort
sudo mount -o loop "$WORK_DIR"/wsa/"$ARCH"/system_ext.img "$MOUNT_DIR"/system_ext || abort
echo -e "done\n"

if [ $REMOVE_AMAZON = 'remove' ]; then
    echo "Remove Amazon AppStore"
    find "$MOUNT_DIR"/product/{etc/permissions,etc/sysconfig,framework,priv-app} | grep -e amazon -e venezia | sudo xargs rm -rf
    echo -e "done\n"
fi

if [ "$ROOT_SOL" = 'magisk' ] || [ "$ROOT_SOL" = '' ]; then
    echo "Integrate Magisk"
    sudo mkdir "$MOUNT_DIR"/sbin
    sudo chcon --reference "$MOUNT_DIR"/init.environ.rc "$MOUNT_DIR"/sbin
    sudo chown root:root "$MOUNT_DIR"/sbin
    sudo chmod 0700 "$MOUNT_DIR"/sbin
    sudo cp "$WORK_DIR"/magisk/magisk/* "$MOUNT_DIR"/sbin/
    sudo cp "$DOWNLOAD_DIR"/magisk.zip "$MOUNT_DIR"/sbin/magisk.apk
    sudo tee -a "$MOUNT_DIR"/sbin/loadpolicy.sh <<EOF
#!/system/bin/sh
mkdir -p /data/adb/magisk
cp /sbin/* /data/adb/magisk/
chmod -R 755 /data/adb/magisk
restorecon -R /data/adb/magisk
for module in \$(ls /data/adb/modules); do
    if ! [ -f "/data/adb/modules/\$module/disable" ] && [ -f "/data/adb/modules/\$module/sepolicy.rule" ]; then
        /sbin/magiskpolicy --live --apply "/data/adb/modules/\$module/sepolicy.rule"
    fi
done
EOF

    sudo find "$MOUNT_DIR"/sbin -type f -exec chmod 0755 {} \;
    sudo find "$MOUNT_DIR"/sbin -type f -exec chown root:root {} \;
    sudo find "$MOUNT_DIR"/sbin -type f -exec chcon --reference "$MOUNT_DIR"/product {} \;
    sudo patchelf --replace-needed libc.so "../linker/libc.so" "$WORK_DIR"/magisk/magiskpolicy || abort
    sudo patchelf --replace-needed libm.so "../linker/libm.so" "$WORK_DIR"/magisk/magiskpolicy || abort
    sudo patchelf --replace-needed libdl.so "../linker/libdl.so" "$WORK_DIR"/magisk/magiskpolicy || abort
    sudo patchelf --set-interpreter "../linker/linker64" "$WORK_DIR"/magisk/magiskpolicy || abort
    chmod +x "$WORK_DIR"/magisk/magiskpolicy
    TMP_PATH=$(Gen_Rand_Str 8)
    echo "/dev/$TMP_PATH(/.*)?    u:object_r:magisk_file:s0" | sudo tee -a "$MOUNT_DIR"/vendor/etc/selinux/vendor_file_contexts
    echo '/data/adb/magisk(/.*)?   u:object_r:magisk_file:s0' | sudo tee -a "$MOUNT_DIR"/vendor/etc/selinux/vendor_file_contexts
    sudo "$WORK_DIR"/magisk/magiskpolicy --load "$MOUNT_DIR"/vendor/etc/selinux/precompiled_sepolicy --save "$MOUNT_DIR"/vendor/etc/selinux/precompiled_sepolicy --magisk "allow * magisk_file lnk_file *"
    SERVER_NAME1=$(Gen_Rand_Str 12)
    SERVER_NAME2=$(Gen_Rand_Str 12)
    SERVER_NAME3=$(Gen_Rand_Str 12)
    SERVER_NAME4=$(Gen_Rand_Str 12)
    sudo tee -a "$MOUNT_DIR"/system/etc/init/hw/init.rc <<EOF
on post-fs-data
    start adbd
    mkdir /dev/$TMP_PATH
    mount tmpfs tmpfs /dev/$TMP_PATH mode=0755
    copy /sbin/magisk64 /dev/$TMP_PATH/magisk64
    chmod 0755 /dev/$TMP_PATH/magisk64
    symlink ./magisk64 /dev/$TMP_PATH/magisk
    symlink ./magisk64 /dev/$TMP_PATH/su
    symlink ./magisk64 /dev/$TMP_PATH/resetprop
    copy /sbin/magisk32 /dev/$TMP_PATH/magisk32
    chmod 0755 /dev/$TMP_PATH/magisk32
    copy /sbin/magiskinit /dev/$TMP_PATH/magiskinit
    chmod 0755 /dev/$TMP_PATH/magiskinit
    copy /sbin/magiskpolicy /dev/$TMP_PATH/magiskpolicy
    chmod 0755 /dev/$TMP_PATH/magiskpolicy
    mkdir /dev/$TMP_PATH/.magisk 700
    mkdir /dev/$TMP_PATH/.magisk/mirror 700
    mkdir /dev/$TMP_PATH/.magisk/block 700
    copy /sbin/magisk.apk /dev/$TMP_PATH/stub.apk
    rm /dev/.magisk_unblock
    start $SERVER_NAME1
    start $SERVER_NAME2
    wait /dev/.magisk_unblock 40
    rm /dev/.magisk_unblock

service $SERVER_NAME1 /system/bin/sh /sbin/loadpolicy.sh
    user root
    seclabel u:r:magisk:s0
    oneshot

service $SERVER_NAME2 /dev/$TMP_PATH/magisk --post-fs-data
    user root
    seclabel u:r:magisk:s0
    oneshot

service $SERVER_NAME3 /dev/$TMP_PATH/magisk --service
    class late_start
    user root
    seclabel u:r:magisk:s0
    oneshot

on property:sys.boot_completed=1
    mkdir /data/adb/magisk 755
    copy /sbin/magisk.apk /data/adb/magisk/magisk.apk
    start $SERVER_NAME4

service $SERVER_NAME4 /dev/$TMP_PATH/magisk --boot-complete
    user root
    seclabel u:r:magisk:s0
    oneshot
EOF
echo -e "Integrate Magisk done\n"
fi

echo "Merge Language Resources"
cp "$WORK_DIR"/wsa/"$ARCH"/resources.pri "$WORK_DIR"/wsa/pri/en-us.pri
cp "$WORK_DIR"/wsa/"$ARCH"/AppxManifest.xml "$WORK_DIR"/wsa/xml/en-us.xml
tee "$WORK_DIR"/wsa/priconfig.xml <<EOF
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<resources targetOsVersion="10.0.0" majorVersion="1">
<index root="\" startIndexAt="\">
    <indexer-config type="folder" foldernameAsQualifier="true" filenameAsQualifier="true" qualifierDelimiter="."/>
    <indexer-config type="PRI"/>
</index>
</resources>
EOF
wine64 ../wine/makepri.exe new /pr "$WORK_DIR"/wsa/pri /in MicrosoftCorporationII.WindowsSubsystemForAndroid /cf "$WORK_DIR"/wsa/priconfig.xml /of "$WORK_DIR"/wsa/"$ARCH"/resources.pri /o
sed -i -zE "s/<Resources.*Resources>/<Resources>\n$(cat "$WORK_DIR"/wsa/xml/* | grep -Po '<Resource [^>]*/>' | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/\$/\\$/g' | sed 's/\//\\\//g')\n<\/Resources>/g" "$WORK_DIR"/wsa/"$ARCH"/AppxManifest.xml
echo -e "Merge Language Resources done\n"

echo "Add extra packages"
sudo cp -r ../"$ARCH"/system/* "$MOUNT_DIR" || abort
sudo find "$MOUNT_DIR"/system/priv-app -type d -exec chmod 0755 {} \;
sudo find "$MOUNT_DIR"/system/priv-app -type f -exec chmod 0644 {} \;
sudo find "$MOUNT_DIR"/system/priv-app -exec chcon --reference="$MOUNT_DIR"/system/priv-app {} \;
echo -e "Add extra packages done\n"

if [ $GAPPS_VARIANT != 'none' ] && [ $GAPPS_VARIANT != '' ]; then
    echo "Integrate GApps"
    cp -r ../"$ARCH"/gapps/* "$WORK_DIR"/gapps || abort
    for d in $(find "$WORK_DIR"/gapps -mindepth 1 -type d -type d); do
        sudo chmod 0755 "$d"
        sudo chown root:root "$d"
    done
    for f in $(find "$WORK_DIR"/gapps -type f); do
        type=$(echo "$f" | sed 's/.*\.//')
        if [ "$type" == "sh" ] || [ "$type" == "$f" ]; then
            sudo chmod 0755 "$f"
        else
            sudo chmod 0644 "$f"
        fi
        sudo chown root:root "$f"
        sudo chcon -h --reference="$MOUNT_DIR"/product/etc/permissions/com.android.settings.intelligence.xml "$f"
        sudo chcon --reference="$MOUNT_DIR"/product/etc/permissions/com.android.settings.intelligence.xml "$f"
    done
    shopt -s extglob
    sudo cp --preserve=a -r "$WORK_DIR"/gapps/product/* "$MOUNT_DIR"/product || abort
    sudo rm -rf "$WORK_DIR"/gapps/product || abort
    if [ $GAPPS_BRAND = "MindTheGapps" ]; then
        mv "$WORK_DIR"/gapps/priv-app/* "$WORK_DIR"/gapps/system_ext/priv-app || abort
        sudo cp --preserve=a -r "$WORK_DIR"/gapps/system_ext/* "$MOUNT_DIR"/system_ext/ || abort
        ls "$WORK_DIR"/gapps/system_ext/etc/ | xargs -n 1 -I dir sudo find "$MOUNT_DIR"/system_ext/etc/dir -type f -exec chmod 0644 {} \;
        ls "$WORK_DIR"/gapps/system_ext/etc/ | xargs -n 1 -I dir sudo find "$MOUNT_DIR"/system_ext/etc/dir -type d -exec chcon --reference="$MOUNT_DIR"/system_ext/etc/permissions {} \;
        ls "$WORK_DIR"/gapps/system_ext/etc/ | xargs -n 1 -I dir sudo find "$MOUNT_DIR"/system_ext/etc/dir -type f -exec chcon --reference="$MOUNT_DIR"/system_ext/etc/permissions {} \;
        if [ -e "$MOUNT_DIR"/system_ext/priv-app/SetupWizard ] ; then
            rm -rf "$MOUNT_DIR/system_ext/priv-app/Provision"
        fi
        sudo rm -rf "$WORK_DIR"/gapps/system_ext || abort
    fi
    sudo cp --preserve=a -r "$WORK_DIR"/gapps/* "$MOUNT_DIR"/system || abort

    sudo find "$MOUNT_DIR"/system/{app,etc,framework,priv-app} -exec chown root:root {} \;
    sudo find "$MOUNT_DIR"/product/{app,etc,overlay,priv-app,lib64,lib,framework} -exec chown root:root {} \;

    sudo find "$MOUNT_DIR"/system/{app,etc,framework,priv-app} -type d -exec chmod 0755 {} \;
    sudo find "$MOUNT_DIR"/product/{app,etc,overlay,priv-app,lib64,lib,framework} -type d -exec chmod 0755 {} \;

    sudo find "$MOUNT_DIR"/system/{app,framework,priv-app} -type f -exec chmod 0644 {} \;
    sudo find "$MOUNT_DIR"/product/{app,etc,overlay,priv-app,lib64,lib,framework} -type f -exec chmod 0644 {} \;

    sudo find "$MOUNT_DIR"/system/{app,framework,priv-app} -type d -exec chcon --reference="$MOUNT_DIR"/system/app {} \;
    sudo find "$MOUNT_DIR"/product/{app,etc,overlay,priv-app,lib64,lib,framework} -type d -exec chcon --reference="$MOUNT_DIR"/product/app {} \;

    sudo find "$MOUNT_DIR"/system/{app,framework,priv-app} -type f -exec chcon --reference="$MOUNT_DIR"/system/framework/ext.jar {} \;
    sudo find "$MOUNT_DIR"/product/{app,etc,overlay,priv-app,lib64,lib,framework} -type f -exec chcon --reference="$MOUNT_DIR"/product/etc/permissions/com.android.settings.intelligence.xml {} \;

    if [ $GAPPS_BRAND = "OpenGapps" ]; then
        ls "$WORK_DIR"/gapps/etc/ | xargs -n 1 -I dir sudo find "$MOUNT_DIR"/system/etc/dir -type f -exec chmod 0644 {} \;
        ls "$WORK_DIR"/gapps/etc/ | xargs -n 1 -I dir sudo find "$MOUNT_DIR"/system/etc/dir -type d -exec chcon --reference="$MOUNT_DIR"/system/etc/permissions {} \;
        ls "$WORK_DIR"/gapps/etc/ | xargs -n 1 -I dir sudo find "$MOUNT_DIR"/system/etc/dir -type f -exec chcon --reference="$MOUNT_DIR"/system/etc/permissions {} \;
    else
        sudo find "$MOUNT_DIR"/system_ext/{priv-app,etc} -exec chown root:root {} \;
        sudo find "$MOUNT_DIR"/system_ext/{priv-app,etc} -type d -exec chmod 0755 {} \;
        sudo find "$MOUNT_DIR"/system_ext/{priv-app,etc} -type f -exec chmod 0644 {} \;
        sudo find "$MOUNT_DIR"/system_ext/{priv-app,etc} -type d -exec chcon --reference="$MOUNT_DIR"/system_ext/priv-app {} \;
        sudo find "$MOUNT_DIR"/system_ext/{priv-app,etc} -type f -exec chcon --reference="$MOUNT_DIR"/system_ext/etc/permissions/com.android.settings.xml {} \;
    fi

    sudo patchelf --replace-needed libc.so "../linker/libc.so" "$WORK_DIR"/magisk/magiskpolicy || abort
    sudo patchelf --replace-needed libm.so "../linker/libm.so" "$WORK_DIR"/magisk/magiskpolicy || abort
    sudo patchelf --replace-needed libdl.so "../linker/libdl.so" "$WORK_DIR"/magisk/magiskpolicy || abort
    sudo patchelf --set-interpreter "../linker/linker64" "$WORK_DIR"/magisk/magiskpolicy || abort
    chmod +x "$WORK_DIR"/magisk/magiskpolicy || abort
    sudo "$WORK_DIR"/magisk/magiskpolicy --load "$MOUNT_DIR"/vendor/etc/selinux/precompiled_sepolicy --save "$MOUNT_DIR"/vendor/etc/selinux/precompiled_sepolicy "allow gmscore_app gmscore_app vsock_socket { create connect write read }" "allow gmscore_app device_config_runtime_native_boot_prop file read" "allow gmscore_app system_server_tmpfs dir search" "allow gmscore_app system_server_tmpfs file open" || abort
    echo -e "Integrate GApps done\n"
fi

if [ $GAPPS_VARIANT != 'none' ] && [ $GAPPS_VARIANT != '' ]; then
    echo "Fix GApps prop"
    sudo python3 fixGappsProp.py "$MOUNT_DIR" || abort
    echo -e "done\n"
fi

echo "Umount images"
sudo find "$MOUNT_DIR" -exec touch -amt 200901010000.00 {} \; >/dev/null 2>&1
sudo umount "$MOUNT_DIR"/vendor
sudo umount "$MOUNT_DIR"/product
sudo umount "$MOUNT_DIR"/system_ext
sudo umount "$MOUNT_DIR"
echo -e "done\n"

echo "Shrink images"
e2fsck -yf "$WORK_DIR"/wsa/"$ARCH"/system.img || abort
resize2fs -M "$WORK_DIR"/wsa/"$ARCH"/system.img || abort
e2fsck -yf "$WORK_DIR"/wsa/"$ARCH"/vendor.img || abort
resize2fs -M "$WORK_DIR"/wsa/"$ARCH"/vendor.img || abort
e2fsck -yf "$WORK_DIR"/wsa/"$ARCH"/product.img || abort
resize2fs -M "$WORK_DIR"/wsa/"$ARCH"/product.img || abort
e2fsck -yf "$WORK_DIR"/wsa/"$ARCH"/system_ext.img || abort
resize2fs -M "$WORK_DIR"/wsa/"$ARCH"/system_ext.img || abort
echo -e "Shrink images done\n"

echo "Remove signature and add scripts"
sudo rm -rf "$WORK_DIR"/wsa/"$ARCH"/\[Content_Types\].xml "$WORK_DIR"/wsa/"$ARCH"/AppxBlockMap.xml "$WORK_DIR"/wsa/"$ARCH"/AppxSignature.p7x "$WORK_DIR"/wsa/"$ARCH"/AppxMetadata || abort
cp "$DOWNLOAD_DIR"/vclibs.appx "$DOWNLOAD_DIR"/xaml.appx "$WORK_DIR"/wsa/"$ARCH" || abort
tee "$WORK_DIR"/wsa/"$ARCH"/Install.ps1 <<EOF
# Automated Install script by Midonei
# http://github.com/doneibcn
function Test-Administrator {
    [OutputType([bool])]
    param()
    process {
        [Security.Principal.WindowsPrincipal]\$user = [Security.Principal.WindowsIdentity]::GetCurrent();
        return \$user.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator);
    }
}

function Finish {
    Clear-Host
    Start-Process "wsa://com.topjohnwu.magisk"
    Start-Process "wsa://com.android.vending"
}

if (-not (Test-Administrator)) {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force
    \$proc = Start-Process -PassThru -WindowStyle Hidden -Verb RunAs powershell.exe -Args "-executionpolicy bypass -command Set-Location '\$PSScriptRoot'; &'\$PSCommandPath' EVAL"
    \$proc.WaitForExit()
    if (\$proc.ExitCode -ne 0) {
        Clear-Host
        Write-Warning "Failed to launch start as Administrator\`r\`nPress any key to exit"
        \$null = \$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
    }
    exit
}
elseif ((\$args.Count -eq 1) -and (\$args[0] -eq "EVAL")) {
    Start-Process powershell.exe -Args "-executionpolicy bypass -command Set-Location '\$PSScriptRoot'; &'\$PSCommandPath'"
    exit
}

if (((Test-Path -Path $(ls -Q "$WORK_DIR"/wsa/"$ARCH" | paste -sd "," -)) -eq \$false).Count) {
    Write-Error "Some files are missing in the folder. Please try to build again. Press any key to exist"
    \$null = \$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 1
}

reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /t REG_DWORD /f /v "AllowDevelopmentWithoutDevLicense" /d "1"

\$VMP = Get-WindowsOptionalFeature -Online -FeatureName 'VirtualMachinePlatform'
if (\$VMP.State -ne "Enabled") {
    Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName 'VirtualMachinePlatform'
    Clear-Host
    Write-Warning "Need restart to enable virtual machine platform\`r\`nPress y to restart or press any key to exit"
    \$key = \$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    If ("y" -eq \$key.Character) {
        Restart-Computer -Confirm
    }
    Else {
        exit 1
    }
}

Add-AppxPackage -ForceApplicationShutdown -ForceUpdateFromAnyVersion -Path vclibs.appx
Add-AppxPackage -ForceApplicationShutdown -ForceUpdateFromAnyVersion -Path xaml.appx

\$Installed = \$null
\$Installed = Get-AppxPackage -Name 'MicrosoftCorporationII.WindowsSubsystemForAndroid'

If ((\$null -ne \$Installed) -and (-not (\$Installed.IsDevelopmentMode))) {
    Clear-Host
    Write-Warning "There is already one installed WSA. Please uninstall it first.\`r\`nPress y to uninstall existing WSA or press any key to exit"
    \$key = \$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    If ("y" -eq \$key.Character) {
        Remove-AppxPackage -Package \$Installed.PackageFullName
    }
    Else {
        exit 1
    }
}
Clear-Host
Write-Host "Installing MagiskOnWSA..."
Stop-Process -Name "wsaclient" -ErrorAction "silentlycontinue"
Add-AppxPackage -ForceApplicationShutdown -ForceUpdateFromAnyVersion -Register .\AppxManifest.xml
if (\$?) {
    Finish
}
Elseif (\$null -ne \$Installed) {
    Clear-Host
    Write-Host "Failed to update, try to uninstall existing installation while preserving userdata..."
    Remove-AppxPackage -PreserveApplicationData -Package \$Installed.PackageFullName
    Add-AppxPackage -ForceApplicationShutdown -ForceUpdateFromAnyVersion -Register .\AppxManifest.xml
    if (\$?) {
        Finish
    }
}
Write-Host "All Done\`r\`nPress any key to exit"
\$null = \$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
EOF
echo -e "Remove signature and add scripts done\n"

echo "Generate info"
if [[ "$ROOT_SOL" = "none" ]]; then
    name1=""
elif [[ "$ROOT_SOL" = "" ]]; then
    name1="-with-magisk"
else
    name1="-with-$ROOT_SOL"
fi
if [[ "$GAPPS_VARIANT" = "none" || "$GAPPS_VARIANT" = "" ]]; then
    name2="-NoGApps"
else
    if [ "$GAPPS_VARIANT" != "pico" ] && [ $GAPPS_BRAND = "OpenGapps" ]; then
        echo ":warning: Since OpenGapps doesn't officially support Android 12.1 yet, lock the variant to pico!"
    fi
    name2="-GApps-${GAPPS_VARIANT}"
fi
echo "WSA${name1}${name2}_${ARCH}"
cat "$WORK_DIR"/ENV

echo -e "\nFinishing building...."
rm -rf "$OUTPUT_DIR" || abort
mv "$WORK_DIR"/wsa/"$ARCH" "$OUTPUT_DIR" || abort
echo -e "done\n"

echo "Cleanup Work Directory"
sudo rm -rf "$WORK_DIR"
echo "done"
