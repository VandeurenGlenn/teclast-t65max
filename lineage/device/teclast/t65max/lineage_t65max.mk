# SPDX-License-Identifier: Apache-2.0

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)
$(call inherit-product, device/teclast/t65max/device.mk)
$(call inherit-product, vendor/lineage/config/common_full_tablet.mk)

PRODUCT_NAME := lineage_t65max
PRODUCT_DEVICE := t65max
PRODUCT_MANUFACTURER := Teclast
PRODUCT_BRAND := Teclast
PRODUCT_MODEL := T65Max_ROW

PRODUCT_SHIPPING_API_LEVEL := 31
PRODUCT_GMS_CLIENTID_BASE := android-teclast
