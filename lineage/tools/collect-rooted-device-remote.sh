#!/system/bin/sh
set -u

R=${T65MAX_CAPTURE_DIR:-/data/local/tmp/t65max-a8d4-rooted}
rm -rf "$R"
mkdir -p "$R"

{
    for key in \
      ro.product.product.name ro.product.device ro.product.model \
      ro.product.vendor.device ro.product.vendor.model \
      ro.build.version.release ro.build.version.sdk ro.build.version.security_patch \
      ro.build.fingerprint ro.vendor.build.fingerprint ro.vendor.build.version.release \
      ro.vendor.build.version.sdk ro.vndk.version ro.treble.enabled \
      ro.boot.slot_suffix ro.boot.verifiedbootstate ro.boot.flash.locked \
      ro.boot.dynamic_partitions ro.boot.virtual_ab \
      ro.hardware ro.board.platform ro.soc.manufacturer ro.soc.model \
      ro.crypto.type ro.crypto.state ro.crypto.volume.options \
      ro.crypto.volume.metadata.encryption ro.crypto.dm_default_key.options; do
        printf '%s=%s\n' "$key" "$(getprop "$key")"
    done
} > "$R/properties.txt" 2>&1

{
    uname -a
    cat /proc/version
    printf '\nCMDLINE\n'
    cat /proc/cmdline 2>/dev/null || true
    printf '\nBOOTCONFIG\n'
    # Bootconfig contains device-unique serial fields on this tablet. Keep the
    # boot parameters needed for bring-up but drop identifying values.
    cat /proc/bootconfig 2>/dev/null | \
      grep -Ev 'androidboot\.(serialno|sn1|sn2|imei|meid|socid)[[:space:]]*=' || true
} > "$R/kernel.txt" 2>&1

{
    mount
    printf '\nDF\n'
    df -h
    printf '\nMOUNTINFO\n'
    cat /proc/self/mountinfo
} > "$R/mounts.txt" 2>&1

{
    cat /proc/partitions
    printf '\nBY-NAME\n'
    ls -l /dev/block/by-name
    printf '\nSIZES\n'
    for part in /dev/block/by-name/*; do
        [ -e "$part" ] || continue
        printf '%s\t%s\t%s\n' \
          "$(basename "$part")" \
          "$(readlink -f "$part")" \
          "$(blockdev --getsize64 "$part" 2>/dev/null || true)"
    done
} > "$R/partitions.txt" 2>&1

{
    lpdump 2>/dev/null || true
    printf '\nSNAPSHOTS\n'
    snapshotctl dump 2>/dev/null || true
} > "$R/super.txt" 2>&1

{
    cat /proc/modules
    printf '\nVENDOR RAMDISK/VENDOR_DLKM LOAD LISTS\n'
    find /vendor /vendor_dlkm -type f \
      \( -name 'modules.load*' -o -name 'modules.dep*' -o -name 'modules.alias*' \) \
      -print -exec cat {} \; 2>/dev/null
} > "$R/modules.txt" 2>&1

{
    service list
    printf '\nHIDL/AIDL HALS\n'
    lshal 2>/dev/null || true
    printf '\nDUMPSYS SERVICES\n'
    dumpsys -l
} > "$R/services.txt" 2>&1

{
    getenforce
    sestatus 2>/dev/null || true
    cat /sys/fs/selinux/policyvers 2>/dev/null || true
    printf '\nPROCESS DOMAINS\n'
    ps -AZ
} > "$R/selinux-status.txt" 2>&1

# Record the executable backing every live process and every file-backed
# vendor/ODM mapping. This gives blob curation a stock-runtime ground truth
# without copying process memory or application data.
{
    printf 'EXECUTABLES\n'
    for proc in /proc/[0-9]*; do
        exe=$(readlink "$proc/exe" 2>/dev/null || true)
        [ -n "$exe" ] && printf '%s\n' "$exe"
    done | sort -u

    printf '\nVENDOR_AND_ODM_MAPPINGS\n'
    for maps in /proc/[0-9]*/maps; do
        cat "$maps" 2>/dev/null || true
    done | awk '{
        path = $NF
        sub(/ \(deleted\)$/, "", path)
        if (path ~ /^\/(vendor|odm|vendor_dlkm|odm_dlkm)\//) print path
    }' | sort -u
} > "$R/runtime-vendor-files.txt" 2>&1

dmesg > "$R/dmesg-private.txt" 2>&1 || true
logcat -b all -d '*:W' > "$R/logcat-warnings-private.txt" 2>&1 || true
{
    logcat -b all -d | grep -i 'avc: denied' || true
    printf '\nDMESG AVC\n'
    dmesg | grep -i 'avc: denied' || true
} > "$R/avc-denials-private.txt" 2>&1

find /vendor -xdev \( -type f -o -type l \) -print | sort > "$R/vendor-files.txt"
find /odm -xdev \( -type f -o -type l \) -print 2>/dev/null | sort > "$R/odm-files.txt"
find /product -xdev \( -type f -o -type l \) -print | sort > "$R/product-files.txt"
find /system_ext -xdev \( -type f -o -type l \) -print | sort > "$R/system_ext-files.txt"

if [ -r /proc/config.gz ]; then
    cp /proc/config.gz "$R/kernel-config.gz"
fi

tar -cf "$R/config-files.tar" \
  /vendor/etc /odm/etc /product/etc/vintf /product/etc/permissions \
  /system_ext/etc/vintf /system_ext/etc/init /system_ext/etc/selinux \
  /vendor_dlkm/lib/modules 2>/dev/null || true
tar -cf "$R/device-tree.tar" -C /sys/firmware/devicetree base 2>/dev/null || true

chmod -R a+rX "$R"
exit 0
