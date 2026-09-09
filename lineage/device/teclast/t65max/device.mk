# SPDX-License-Identifier: Apache-2.0

$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_ramdisk.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/userspace_reboot.mk)

PRODUCT_CHARACTERISTICS := tablet
PRODUCT_USE_DYNAMIC_PARTITIONS := true
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/launch_with_vendor_ramdisk.mk)

AB_OTA_UPDATER := true
AB_OTA_PARTITIONS := \
    boot \
    vendor_boot \
    dtbo \
    system \
    system_ext \
    product \
    vendor \
    vendor_dlkm \
    odm_dlkm \
    vbmeta \
    vbmeta_system \
    vbmeta_vendor

PRODUCT_PACKAGES += \
    android.hardware.boot-service.default_recovery \
    fastbootd \
    FrameworkResOverlay \
    FrameworkResOverlayExt \
    libkeystore-engine-wifi-hidl \
    libkeystore-wifi-hidl \
    TabletFrameworkResOverlay \
    update_engine \
    update_engine_sideload \
    update_verifier \
    WifiResOverlay

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/fstab.mt8781:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/first_stage_ramdisk/fstab.mt8781 \
    $(LOCAL_PATH)/rootdir/init.recovery.mt8781.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.mt6789.rc \
    $(LOCAL_PATH)/rootdir/init.recovery.mt8781.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.mt8781.rc

PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH) \
    hardware/mediatek

# This is intentionally last: the generated vendor repository will supply the
# stock A8D3 proprietary HALs, firmware and configuration files.
$(call inherit-product, vendor/teclast/t65max/t65max-vendor.mk)
