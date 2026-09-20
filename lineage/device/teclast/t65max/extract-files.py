#!/usr/bin/env -S PYTHONPATH=../../../tools/extract-utils python3
# SPDX-License-Identifier: Apache-2.0

from extract_utils.fixups_blob import blob_fixup, blob_fixups_user_type
from extract_utils.fixups_lib import lib_fixups
from extract_utils.main import ExtractUtils, ExtractUtilsModule


blob_fixups: blob_fixups_user_type = {
    "vendor/bin/hw/android.hardware.lights-service.mediatek": blob_fixup()
        .replace_needed(
            "android.hardware.light-V1-ndk_platform.so",
            "android.hardware.light-V1-ndk.so",
        ),
    "vendor/bin/hw/android.hardware.memtrack-service.mediatek": blob_fixup()
        .replace_needed(
            "android.hardware.memtrack-V1-ndk_platform.so",
            "android.hardware.memtrack-V1-ndk.so",
        ),
    (
        "vendor/bin/hw/android.hardware.security.keymint-service.trustkernel",
        "vendor/lib64/lib_android_keymaster_keymint_utils_vendor.so",
        "vendor/lib64/libkeymint_vendor.so",
    ): blob_fixup()
        .replace_needed(
            "android.hardware.security.keymint-V1-ndk_platform.so",
            "android.hardware.security.keymint-V1-ndk.so",
        )
        .replace_needed(
            "android.hardware.security.sharedsecret-V1-ndk_platform.so",
            "android.hardware.security.sharedsecret-V1-ndk.so",
        )
        .replace_needed(
            "android.hardware.security.secureclock-V1-ndk_platform.so",
            "android.hardware.security.secureclock-V1-ndk.so",
        )
        .replace_needed(
            "lib_android_keymaster_keymint_utils.so",
            "lib_android_keymaster_keymint_utils_vendor.so",
        )
        .replace_needed(
            "libkeymint.so",
            "libkeymint_vendor.so",
        )
        .replace_needed(
            "libcppbor_external.so",
            "libcppbor_external_vendor.so",
        )
        .replace_needed(
            "libcppcose_rkp.so",
            "libcppcose_rkp_vendor.so",
        )
        .replace_needed(
            "libkeymaster_messages.so",
            "libkeymaster_messages_vendor.so",
        )
        .replace_needed(
            "libkeymaster_portable.so",
            "libkeymaster_portable_vendor.so",
        )
        .replace_needed(
            "libpuresoftkeymasterdevice.so",
            "libpuresoftkeymasterdevice_vendor.so",
        )
        .replace_needed(
            "libsoft_attestation_cert.so",
            "libsoft_attestation_cert_vendor.so",
        ),
    (
        "vendor/lib64/libcppbor_external_vendor.so",
        "vendor/lib64/libcppcose_rkp_vendor.so",
        "vendor/lib64/libkeymaster_messages_vendor.so",
        "vendor/lib64/libkeymaster_portable_vendor.so",
        "vendor/lib64/libpuresoftkeymasterdevice_vendor.so",
        "vendor/lib64/libsoft_attestation_cert_vendor.so",
    ): blob_fixup()
        .replace_needed("libcppbor_external.so", "libcppbor_external_vendor.so")
        .replace_needed("libcppcose_rkp.so", "libcppcose_rkp_vendor.so")
        .replace_needed("libkeymaster_messages.so", "libkeymaster_messages_vendor.so")
        .replace_needed("libkeymaster_portable.so", "libkeymaster_portable_vendor.so")
        .replace_needed("libpuresoftkeymasterdevice.so", "libpuresoftkeymasterdevice_vendor.so")
        .replace_needed("libsoft_attestation_cert.so", "libsoft_attestation_cert_vendor.so"),
    (
        "vendor/bin/hw/android.hardware.audio.service.mediatek",
        "vendor/lib64/android.hardware.audio@7.0-util.so",
        "vendor/lib64/android.hardware.audio.common@6.0-util.so",
        "vendor/lib64/android.hardware.audio.common@7.0-util.so",
        "vendor/lib64/android.hardware.audio.effect@6.0-util.so",
        "vendor/lib64/android.hardware.audio.effect@7.0-util.so",
        "vendor/lib64/hw/android.hardware.audio.effect@6.0-impl.so",
        "vendor/lib64/hw/android.hardware.audio.effect@7.0-impl.so",
        "vendor/lib64/hw/android.hardware.audio@6.0-impl-mediatek.so",
        "vendor/lib64/hw/android.hardware.audio@7.0-impl-mediatek.so",
        "vendor/lib64/hw/audio.primary.mediatek.so",
        "vendor/lib64/hw/audio.usb.default.so",
        "vendor/lib64/libeffects.so",
        "vendor/lib64/android.hardware.audio.common-util_vendor.so",
        "vendor/lib64/audioclient-types-aidl-cpp_vendor.so",
        "vendor/lib64/framework-permission-aidl-cpp_vendor.so",
        "vendor/lib64/libalsautils_vendor.so",
        "vendor/lib64/libaudioclient_aidl_conversion_vendor.so",
        "vendor/lib64/libaudiofoundation_vendor.so",
        "vendor/lib64/libeffectsconfig_vendor.so",
        "vendor/lib64/libshmemcompat_vendor.so",
        "vendor/lib64/libshmemutil_vendor.so",
        "vendor/lib64/shared-file-region-aidl-cpp_vendor.so",
    ): blob_fixup()
        .replace_needed("android.hardware.audio.common-util.so", "android.hardware.audio.common-util_vendor.so")
        .replace_needed("audioclient-types-aidl-cpp.so", "audioclient-types-aidl-cpp_vendor.so")
        .replace_needed("framework-permission-aidl-cpp.so", "framework-permission-aidl-cpp_vendor.so")
        .replace_needed("libalsautils.so", "libalsautils_vendor.so")
        .replace_needed("libaudioclient_aidl_conversion.so", "libaudioclient_aidl_conversion_vendor.so")
        .replace_needed("libaudiofoundation.so", "libaudiofoundation_vendor.so")
        .replace_needed("libeffectsconfig.so", "libeffectsconfig_vendor.so")
        .replace_needed("libshmemcompat.so", "libshmemcompat_vendor.so")
        .replace_needed("libshmemutil.so", "libshmemutil_vendor.so")
        .replace_needed("shared-file-region-aidl-cpp.so", "shared-file-region-aidl-cpp_vendor.so"),
    (
        "vendor/lib64/libtflite_mtk.so",
        "vendor/lib64/libflatbuffers-cpp_vendor.so",
        "vendor/lib64/libruy_vendor.so",
        "vendor/lib64/libtextclassifier_hash_vendor.so",
    ): blob_fixup()
        .replace_needed("libflatbuffers-cpp.so", "libflatbuffers-cpp_vendor.so")
        .replace_needed("libruy.so", "libruy_vendor.so")
        .replace_needed("libtextclassifier_hash.so", "libtextclassifier_hash_vendor.so"),
    (
        "vendor/bin/getgameserver",
        "vendor/lib64/libpcap_vendor.so",
    ): blob_fixup()
        .replace_needed("libpcap.so", "libpcap_vendor.so"),
    "vendor/bin/hw/android.hardware.vibrator-service.mediatek": blob_fixup()
        .replace_needed(
            "android.hardware.vibrator-V2-ndk_platform.so",
            "android.hardware.vibrator-V2-ndk.so",
        ),
    (
        "vendor/bin/hw/android.hardware.gnss-service.mediatek",
        "vendor/lib64/hw/android.hardware.gnss-impl-mediatek.so",
    ): blob_fixup()
        .replace_needed(
            "android.hardware.gnss-V1-ndk_platform.so",
            "android.hardware.gnss-V1-ndk.so",
        ),
    (
        "vendor/lib64/mt6789/lib3a.ae.stat.so",
        "vendor/lib64/mt6789/lib3a.flash.so",
        "vendor/lib64/mt6789/lib3a.sensors.color.so",
        "vendor/lib64/mt6789/lib3a.sensors.flicker.so",
    ): blob_fixup()
        .add_needed("liblog.so"),
    (
        "vendor/lib64/mt6789/libmnl.so",
        "vendor/lib64/libmtk-ril.so",
    ): blob_fixup()
        .add_needed("libcutils.so"),
    (
        "vendor/bin/hw/vendor.mediatek.hardware.mtkpower@1.0-service",
        "vendor/lib64/android.hardware.power-service-mediatek.so",
    ): blob_fixup()
        .replace_needed(
            "android.hardware.power-V2-ndk_platform.so",
            "android.hardware.power-V2-ndk.so",
        ),
}  # fmt: skip


# Start without inherited Xiaomi fixups. Each compatibility patch must be
# justified by an observed T65 Max linker, service, VINTF, or SELinux failure.
module = ExtractUtilsModule(
    "t65max",
    "teclast",
    blob_fixups=blob_fixups,
    lib_fixups=lib_fixups,
    namespace_imports=[
        "device/teclast/t65max",
        "hardware/mediatek",
    ],
    check_elf=True,
    add_firmware_proprietary_file=True,
)

if __name__ == "__main__":
    ExtractUtils.device(module).run()
