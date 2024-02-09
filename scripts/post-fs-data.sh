#!/system/bin/sh
MAGISKTMP=/sbin
[ -d /sbin ] || MAGISKTMP=/debug_ramdisk
MAGISKBIN=/data/adb/magisk
if [ ! -f $MAGISKBIN/magiskpolicy ]; then
    # shellcheck disable=SC2174
    mkdir -p -m 755 $MAGISKBIN
    chcon u:object_r:system_file:s0 $MAGISKBIN
    ABI=$(/system/bin/getprop ro.product.cpu.abi)
    /system/bin/unzip -d $MAGISKBIN -j $MAGISKTMP/stub.apk "lib/$ABI/libmagiskpolicy.so"
    mv $MAGISKBIN/libmagiskpolicy.so $MAGISKBIN/magiskpolicy
    chmod 755 $MAGISKBIN/magiskpolicy
fi
[ -f $MAGISKTMP/sepolicy.rule ] && $MAGISKBIN/magiskpolicy --live --apply $MAGISKTMP/sepolicy.rule
