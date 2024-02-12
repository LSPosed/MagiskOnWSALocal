#!/system/bin/sh
MAGISKTMP=/sbin
[ -d /sbin ] || MAGISKTMP=/debug_ramdisk
MAGISKBIN=/data/adb/magisk
if [ ! -d /data/adb ]; then
    mkdir -m 700 /data/adb
    chcon u:object_r:adb_data_file:s0 /data/adb
fi
if [ ! -d $MAGISKBIN ]; then
    # shellcheck disable=SC2174
    mkdir -p -m 755 $MAGISKBIN
    chcon u:object_r:system_file:s0 $MAGISKBIN
fi
ABI=$(/system/bin/getprop ro.product.cpu.abi)
for file in busybox magiskpolicy magiskboot magiskinit; do
    [ -x "$MAGISKBIN/$file" ] || {
        /system/bin/unzip -d $MAGISKBIN -j $MAGISKTMP/stub.apk "lib/$ABI/lib$file.so"
        mv $MAGISKBIN/lib$file.so $MAGISKBIN/$file
        chmod 755 "$MAGISKBIN/$file"
    }
done
for file in util_functions.sh boot_patch.sh; do
    [ -x "$MAGISKBIN/$file" ] || {
        /system/bin/unzip -d $MAGISKBIN -j $MAGISKTMP/stub.apk "assets/$file"
        chmod 755 "$MAGISKBIN/$file"
    }
done
