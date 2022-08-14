#!/bin/bash

function Radiolist {
    declare -A o="$1"
    shift
    whiptail --nocancel --radiolist "${o[title]}" \
        0 0 0 "$@" 3>&1 1>&2 2>&3
    if [ $? != 0 ]; then
        echo "${o[default]}"
    fi
}

function YesNoBox {
    declare -A o="$1"
    shift
    whiptail --title "${o[title]}" --yesno "${o[text]}" 0 0
}

echo "Dependencies"
sudo apt update && sudo apt -y install setools lzip wine winetricks patchelf
cp -r ../wine/.cache/* ~/.cache
winetricks msxml6

# ARCH=$(whiptail --nocancel --separate-output --checklist 'Build arch' 0 0 0 'x64' "X86_64" 'on' 'arm64' "AArch64" 'off' 3>&1 1>&2 2>&3)
# if [ $? != 0 ]; then
#     ARCH=x64
# fi

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
    if [ -f ../download/MindTheGapps/MindTheGapps_$ARCH.zip ]; then
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
echo -e "ARCH=$ARCH\nRELEASE_TYPE=$RELEASE_TYPE\nMAGISK_VER=$MAGISK_VER\nGAPPS_VARIANT=$GAPPS_VARIANT\nREMOVE_AMAZON=$REMOVE_AMAZON\nROOT_SOL=$ROOT_SOL"

echo "Download WSA"
python3 downloadWSA.py "$ARCH" "$RELEASE_TYPE"

echo "extractWSA"
WSA_WORK_ENV=../workdir/ENV
if [ -f $WSA_WORK_ENV ]; then rm -f $WSA_WORK_ENV; fi
export WSA_WORK_ENV
python3 extractWSA.py "$ARCH"

echo "Download Magisk"
python3 downloadMagisk.py "$ARCH" "$MAGISK_VER"

if [ $GAPPS_VARIANT != 'none' ] && [ $GAPPS_VARIANT != '' ]; then
    if [ $GAPPS_BRAND = "OpenGapps" ]; then
        echo "Download OpenGApps"
        python3 downloadGapps.py "$ARCH" "$MAGISK_VER"
    fi
    echo "Extract GApps"
    mkdir -p ../workdir/gapps
    if [ $GAPPS_BRAND = "OpenGapps" ]; then
        unzip -p ../download/gapps.zip {Core,GApps}/'*.lz' | tar --lzip -C ../workdir/gapps -xvf - -i --strip-components=2 --exclude='setupwizardtablet-x86_64' --exclude='packageinstallergoogle-all' --exclude='speech-common' --exclude='markup-lib-arm' --exclude='markup-lib-arm64' --exclude='markup-all' --exclude='setupwizarddefault-x86_64' --exclude='pixellauncher-all' --exclude='pixellauncher-common'
    else
        unzip ../download/MindTheGapps/MindTheGapps_$ARCH.zip "system/*" -x "system/addon.d/*" "system/system_ext/priv-app/SetupWizard/*" -d ../workdir/gapps
        mv ../workdir/gapps/system/* ../workdir/gapps
        rm -rf ../workdir/gapps/system
    fi
fi

echo "Expand images"

e2fsck -yf ../workdir/wsa/$ARCH/system_ext.img
SYSTEM_EXT_SIZE=$(($(du -sB512 ../workdir/wsa/$ARCH/system_ext.img | cut -f1) + 20000))
if [ -d ../workdir/gapps/system_ext ]; then
    SYSTEM_EXT_SIZE=$(($SYSTEM_EXT_SIZE + $(du -sB512 ../workdir/gapps/system_ext | cut -f1)))
fi
resize2fs ../workdir/wsa/$ARCH/system_ext.img "$SYSTEM_EXT_SIZE"s

e2fsck -yf ../workdir/wsa/$ARCH/product.img
PRODUCT_SIZE=$(($(du -sB512 ../workdir/wsa/$ARCH/product.img | cut -f1) + 20000))
if [ -d ../workdir/gapps/product ]; then
    PRODUCT_SIZE=$(($PRODUCT_SIZE + $(du -sB512 ../workdir/gapps/product | cut -f1)))
fi
resize2fs ../workdir/wsa/$ARCH/product.img "$PRODUCT_SIZE"s

e2fsck -yf ../workdir/wsa/$ARCH/system.img
SYSTEM_SIZE=$(($(du -sB512 ../workdir/wsa/$ARCH/system.img | cut -f1) + 20000))
if [ -d ../workdir/gapps ]; then
    SYSTEM_SIZE=$(($SYSTEM_SIZE + $(du -sB512 ../workdir/gapps | cut -f1) - $(du -sB512 ../workdir/gapps/product | cut -f1)))
    if [ -d ../workdir/gapps/system_ext ]; then
        SYSTEM_SIZE=$(($SYSTEM_SIZE - $(du -sB512 ../workdir/gapps/system_ext | cut -f1)))
    fi
fi
if [ -d ../workdir/magisk ]; then
    SYSTEM_SIZE=$(($SYSTEM_SIZE + $(du -sB512 ../workdir/magisk/magisk | cut -f1)))
fi
if [ -f ../download/magisk.zip ]; then
    SYSTEM_SIZE=$(($SYSTEM_SIZE + $(du -sB512 ../download/magisk.zip | cut -f1)))
fi
resize2fs ../workdir/wsa/$ARCH/system.img "$SYSTEM_SIZE"s

e2fsck -yf ../workdir/wsa/$ARCH/vendor.img
VENDOR_SIZE=$(($(du -sB512 ../workdir/wsa/$ARCH/vendor.img | cut -f1) + 20000))
resize2fs ../workdir/wsa/$ARCH/vendor.img "$VENDOR_SIZE"s

echo "Mount images"
MOUNT_DIR=../workdir/system
sudo mkdir $MOUNT_DIR
sudo mount -o loop ../workdir/wsa/$ARCH/system.img $MOUNT_DIR
sudo mount -o loop ../workdir/wsa/$ARCH/vendor.img $MOUNT_DIR/vendor
sudo mount -o loop ../workdir/wsa/$ARCH/product.img $MOUNT_DIR/product
sudo mount -o loop ../workdir/wsa/$ARCH/system_ext.img $MOUNT_DIR/system_ext

if [ $REMOVE_AMAZON = 'remove' ]; then
    echo "Remove Amazon AppStore"
    find $MOUNT_DIR/product/{etc/permissions,etc/sysconfig,framework,priv-app} | grep -e amazon -e venezia | sudo xargs rm -rf
fi

if [ $ROOT_SOL = 'magisk' ] || [ $ROOT_SOL = '' ]; then
    echo "Integrate Magisk"
    sudo mkdir $MOUNT_DIR/sbin
    sudo chcon --reference $MOUNT_DIR/init.environ.rc $MOUNT_DIR/sbin
    sudo chown root:root $MOUNT_DIR/sbin
    sudo chmod 0700 $MOUNT_DIR/sbin
    sudo cp ../workdir/magisk/magisk/* $MOUNT_DIR/sbin/
    sudo cp ../download/magisk.zip $MOUNT_DIR/sbin/magisk.apk
    sudo tee -a $MOUNT_DIR/sbin/loadpolicy.sh <<EOF
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

    sudo find $MOUNT_DIR/sbin -type f -exec chmod 0755 {} \;
    sudo find $MOUNT_DIR/sbin -type f -exec chown root:root {} \;
    sudo find $MOUNT_DIR/sbin -type f -exec chcon --reference $MOUNT_DIR/product {} \;
    sudo patchelf --replace-needed libc.so "../linker/libc.so" ../workdir/magisk/magiskpolicy || true
    sudo patchelf --replace-needed libm.so "../linker/libm.so" ../workdir/magisk/magiskpolicy || true
    sudo patchelf --replace-needed libdl.so "../linker/libdl.so" ../workdir/magisk/magiskpolicy || true
    sudo patchelf --set-interpreter "../linker/linker64" ../workdir/magisk/magiskpolicy || true
    chmod +x ../workdir/magisk/magiskpolicy
    echo '/dev/wsa-magisk(/.*)?    u:object_r:magisk_file:s0' | sudo tee -a $MOUNT_DIR/vendor/etc/selinux/vendor_file_contexts
    echo '/data/adb/magisk(/.*)?   u:object_r:magisk_file:s0' | sudo tee -a $MOUNT_DIR/vendor/etc/selinux/vendor_file_contexts
    sudo ../workdir/magisk/magiskpolicy --load $MOUNT_DIR/vendor/etc/selinux/precompiled_sepolicy --save $MOUNT_DIR/vendor/etc/selinux/precompiled_sepolicy --magisk "allow * magisk_file lnk_file *"
    sudo tee -a $MOUNT_DIR/system/etc/init/hw/init.rc <<EOF
on post-fs-data
    start logd
    start adbd
    mkdir /dev/wsa-magisk
    mount tmpfs tmpfs /dev/wsa-magisk mode=0755
    copy /sbin/magisk64 /dev/wsa-magisk/magisk64
    chmod 0755 /dev/wsa-magisk/magisk64
    symlink ./magisk64 /dev/wsa-magisk/magisk
    symlink ./magisk64 /dev/wsa-magisk/su
    symlink ./magisk64 /dev/wsa-magisk/resetprop
    copy /sbin/magisk32 /dev/wsa-magisk/magisk32
    chmod 0755 /dev/wsa-magisk/magisk32
    copy /sbin/magiskinit /dev/wsa-magisk/magiskinit
    chmod 0755 /dev/wsa-magisk/magiskinit
    copy /sbin/magiskpolicy /dev/wsa-magisk/magiskpolicy
    chmod 0755 /dev/wsa-magisk/magiskpolicy
    mkdir /dev/wsa-magisk/.magisk 700
    mkdir /dev/wsa-magisk/.magisk/mirror 700
    mkdir /dev/wsa-magisk/.magisk/block 700
    copy /sbin/magisk.apk /dev/wsa-magisk/stub.apk
    rm /dev/.magisk_unblock
    start IhhslLhHYfse
    start FAhW7H9G5sf
    wait /dev/.magisk_unblock 40
    rm /dev/.magisk_unblock

service IhhslLhHYfse /system/bin/sh /sbin/loadpolicy.sh
    user root
    seclabel u:r:magisk:s0
    oneshot

service FAhW7H9G5sf /dev/wsa-magisk/magisk --post-fs-data
    user root
    seclabel u:r:magisk:s0
    oneshot

service HLiFsR1HtIXVN6 /dev/wsa-magisk/magisk --service
    class late_start
    user root
    seclabel u:r:magisk:s0
    oneshot

on property:sys.boot_completed=1
    mkdir /data/adb/magisk 755
    copy /sbin/magisk.apk /data/adb/magisk/magisk.apk
    start YqCTLTppv3ML

service YqCTLTppv3ML /dev/wsa-magisk/magisk --boot-complete
    user root
    seclabel u:r:magisk:s0
    oneshot
EOF
fi

echo "Merge Language Resources"
cp ../workdir/wsa/$ARCH/resources.pri ../workdir/wsa/pri/en-us.pri
cp ../workdir/wsa/$ARCH/AppxManifest.xml ../workdir/wsa/xml/en-us.xml
tee ../workdir/wsa/priconfig.xml <<EOF
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<resources targetOsVersion="10.0.0" majorVersion="1">
<index root="\" startIndexAt="\">
    <indexer-config type="folder" foldernameAsQualifier="true" filenameAsQualifier="true" qualifierDelimiter="."/>
    <indexer-config type="PRI"/>
</index>
</resources>
EOF
wine64 ../wine/makepri.exe new /pr ../workdir/wsa/pri /in MicrosoftCorporationII.WindowsSubsystemForAndroid /cf ../workdir/wsa/priconfig.xml /of ../workdir/wsa/$ARCH/resources.pri /o
sed -i -zE "s/<Resources.*Resources>/<Resources>\n$(cat ../workdir/wsa/xml/* | grep -Po '<Resource [^>]*/>' | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/\$/\\$/g' | sed 's/\//\\\//g')\n<\/Resources>/g" ../workdir/wsa/$ARCH/AppxManifest.xml

echo "Add extra packages"
sudo cp -r ""../$ARCH/system/*"" $MOUNT_DIR
sudo find $MOUNT_DIR/system/priv-app -type d -exec chmod 0755 {} \;
sudo find $MOUNT_DIR/system/priv-app -type f -exec chmod 0644 {} \;
sudo find $MOUNT_DIR/system/priv-app -exec chcon --reference=$MOUNT_DIR/system/priv-app {} \;

if [ $GAPPS_VARIANT != 'none' ] && [ $GAPPS_VARIANT != '' ]; then
    echo "Integrate GApps"
    cp -r ../$ARCH/gapps/* ../workdir/gapps
    for d in $(find ../workdir/gapps -mindepth 1 -type d -type d); do
        sudo chmod 0755 $d
        sudo chown root:root $d
    done
    for f in $(find ../workdir/gapps -type f); do
        type=$(echo "$f" | sed 's/.*\.//')
        if [ "$type" == "sh" ] || [ "$type" == "$f" ]; then
            sudo chmod 0755 $f
        else
            sudo chmod 0644 $f
        fi
        sudo chown root:root $f
        sudo chcon -h --reference=$MOUNT_DIR/product/etc/permissions/com.android.settings.intelligence.xml $f
        sudo chcon --reference=$MOUNT_DIR/product/etc/permissions/com.android.settings.intelligence.xml $f
    done
    shopt -s extglob
    sudo cp -vr ../workdir/gapps/product/* $MOUNT_DIR/product/
    rm -rf ../workdir/gapps/product
    if [ $GAPPS_BRAND = "MindTheGapps" ]; then
        mv ../workdir/gapps/priv-app/* ../workdir/gapps/system_ext/priv-app
        sudo cp --preserve=a -vr ../workdir/gapps/system_ext/* $MOUNT_DIR/system_ext/
        ls ../workdir/gapps/system_ext/etc/ | xargs -n 1 -I dir sudo find $MOUNT_DIR/system_ext/etc/dir -type f -exec chmod 0644 {} \;
        ls ../workdir/gapps/system_ext/etc/ | xargs -n 1 -I dir sudo find $MOUNT_DIR/system_ext/etc/dir -type d -exec chcon --reference=$MOUNT_DIR/system_ext/etc/permissions {} \;
        ls ../workdir/gapps/system_ext/etc/ | xargs -n 1 -I dir sudo find $MOUNT_DIR/system_ext/etc/dir -type f -exec chcon --reference=$MOUNT_DIR/system_ext/etc/permissions {} \;

        rm -rf ../workdir/gapps/system_ext
    fi
    sudo cp -vr ../workdir/gapps/* $MOUNT_DIR/system

    sudo find $MOUNT_DIR/system/{app,etc,framework,priv-app} -exec chown root:root {} \;
    sudo find $MOUNT_DIR/product/{app,etc,overlay,priv-app,lib64,lib,framework} -exec chown root:root {} \;

    sudo find $MOUNT_DIR/system/{app,etc,framework,priv-app} -type d -exec chmod 0755 {} \;
    sudo find $MOUNT_DIR/product/{app,etc,overlay,priv-app,lib64,lib,framework} -type d -exec chmod 0755 {} \;

    sudo find $MOUNT_DIR/system/{app,framework,priv-app} -type f -exec chmod 0644 {} \;
    sudo find $MOUNT_DIR/product/{app,etc,overlay,priv-app,lib64,lib,framework} -type f -exec chmod 0644 {} \;

    sudo find $MOUNT_DIR/system/{app,framework,priv-app} -type d -exec chcon --reference=$MOUNT_DIR/system/app {} \;
    sudo find $MOUNT_DIR/product/{app,etc,overlay,priv-app,lib64,lib,framework} -type d -exec chcon --reference=$MOUNT_DIR/product/app {} \;

    sudo find $MOUNT_DIR/system/{app,framework,priv-app} -type f -exec chcon --reference=$MOUNT_DIR/system/framework/ext.jar {} \;
    sudo find $MOUNT_DIR/product/{app,etc,overlay,priv-app,lib64,lib,framework} -type f -exec chcon --reference=$MOUNT_DIR/product/etc/permissions/com.android.settings.intelligence.xml {} \;

    if [ $GAPPS_BRAND = "OpenGapps" ]; then
        ls ../workdir/gapps/etc/ | xargs -n 1 -I dir sudo find $MOUNT_DIR/system/etc/dir -type f -exec chmod 0644 {} \;
        ls ../workdir/gapps/etc/ | xargs -n 1 -I dir sudo find $MOUNT_DIR/system/etc/dir -type d -exec chcon --reference=$MOUNT_DIR/system/etc/permissions {} \;
        ls ../workdir/gapps/etc/ | xargs -n 1 -I dir sudo find $MOUNT_DIR/system/etc/dir -type f -exec chcon --reference=$MOUNT_DIR/system/etc/permissions {} \;
    else
        sudo find $MOUNT_DIR/system_ext/{priv-app,etc} -exec chown root:root {} \;
        sudo find $MOUNT_DIR/system_ext/{priv-app,etc} -type d -exec chmod 0755 {} \;
        sudo find $MOUNT_DIR/system_ext/{priv-app,etc} -type f -exec chmod 0644 {} \;
        sudo find $MOUNT_DIR/system_ext/{priv-app,etc} -type d -exec chcon --reference=$MOUNT_DIR/system_ext/priv-app {} \;
        sudo find $MOUNT_DIR/system_ext/{priv-app,etc} -type f -exec chcon --reference=$MOUNT_DIR/system_ext/etc/permissions/com.android.settings.xml {} \;
    fi

    sudo patchelf --replace-needed libc.so "../linker/libc.so" ../workdir/magisk/magiskpolicy || true
    sudo patchelf --replace-needed libm.so "../linker/libm.so" ../workdir/magisk/magiskpolicy || true
    sudo patchelf --replace-needed libdl.so "../linker/libdl.so" ../workdir/magisk/magiskpolicy || true
    sudo patchelf --set-interpreter "../linker/linker64" ../workdir/magisk/magiskpolicy || true
    chmod +x ../workdir/magisk/magiskpolicy
    sudo ../workdir/magisk/magiskpolicy --load $MOUNT_DIR/vendor/etc/selinux/precompiled_sepolicy --save $MOUNT_DIR/vendor/etc/selinux/precompiled_sepolicy "allow gmscore_app gmscore_app vsock_socket { create connect write read }" "allow gmscore_app device_config_runtime_native_boot_prop file read" "allow gmscore_app system_server_tmpfs dir search" "allow gmscore_app system_server_tmpfs file open"

fi

if [ $GAPPS_VARIANT != 'none' ] && [ $GAPPS_VARIANT != '' ]; then
    echo "Fix GApps prop"
    sudo python3 fixGappsProp.py $MOUNT_DIR
fi

echo "Umount images"
sudo find $MOUNT_DIR -exec touch -amt 200901010000.00 {} \; >/dev/null 2>&1
sudo umount $MOUNT_DIR/vendor
sudo umount $MOUNT_DIR/product
sudo umount $MOUNT_DIR/system_ext
sudo umount $MOUNT_DIR

echo "Shrink images"
e2fsck -yf ../workdir/wsa/$ARCH/system.img
resize2fs -M ../workdir/wsa/$ARCH/system.img
e2fsck -yf ../workdir/wsa/$ARCH/vendor.img
resize2fs -M ../workdir/wsa/$ARCH/vendor.img
e2fsck -yf ../workdir/wsa/$ARCH/product.img
resize2fs -M ../workdir/wsa/$ARCH/product.img
e2fsck -yf ../workdir/wsa/$ARCH/system_ext.img
resize2fs -M ../workdir/wsa/$ARCH/system_ext.img

echo "Remove signature and add scripts"
rm -rf ../workdir/wsa/$ARCH/\[Content_Types\].xml ../workdir/wsa/$ARCH/AppxBlockMap.xml ../workdir/wsa/$ARCH/AppxSignature.p7x ../workdir/wsa/$ARCH/AppxMetadata
cp ../download/vclibs.appx ../download/xaml.appx ../workdir/wsa/$ARCH
tee ../workdir/wsa/$ARCH/Install.ps1 <<EOF
# Automated Install script by Mioki
# http://github.com/okibcn
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

if (((Test-Path -Path $(ls -Q ../workdir/wsa/$ARCH | paste -sd "," -)) -eq \$false).Count) {
    Write-Error "Some files are missing in the zip. Please try to download it again from the browser downloader, or try to run the workflow again. Press any key to exist"
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
cat ../workdir/ENV
rm -rf ../output
mv ../workdir/wsa/$ARCH ../output
rm -rf ../workdir
