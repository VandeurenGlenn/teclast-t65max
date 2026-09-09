# SPDX-License-Identifier: Apache-2.0

LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_DEVICE),t65max)

# extract-utils cannot generate package modules for stock APKs installed under
# vendor/overlay. Keep them extract-only and expose them as proper prebuilts.
define t65max-vendor-overlay
include $$(CLEAR_VARS)
LOCAL_MODULE := $(1)
LOCAL_MODULE_CLASS := APPS
LOCAL_MODULE_SUFFIX := $$(COMMON_ANDROID_PACKAGE_SUFFIX)
LOCAL_CERTIFICATE := PRESIGNED
LOCAL_DEX_PREOPT := false
LOCAL_PREBUILT_MODULE_FILE := vendor/teclast/t65max/proprietary/vendor/overlay/$(1)/$(1).apk
LOCAL_MODULE_PATH := $$(TARGET_OUT_VENDOR)/overlay/$(1)
include $$(BUILD_PREBUILT)
endef

$(eval $(call t65max-vendor-overlay,FrameworkResOverlay))
$(eval $(call t65max-vendor-overlay,FrameworkResOverlayExt))
$(eval $(call t65max-vendor-overlay,TabletFrameworkResOverlay))
$(eval $(call t65max-vendor-overlay,WifiResOverlay))

endif
