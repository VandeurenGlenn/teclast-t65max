#!/usr/bin/env -S PYTHONPATH=../../../tools/extract-utils python3
# SPDX-License-Identifier: Apache-2.0

from extract_utils.main import ExtractUtils, ExtractUtilsModule


# Start without inherited Xiaomi fixups. Each compatibility patch must be
# justified by an observed T65 Max linker, service, VINTF, or SELinux failure.
module = ExtractUtilsModule(
    "t65max",
    "teclast",
    namespace_imports=[
        "device/teclast/t65max",
        "hardware/mediatek",
        "hardware/lineage/compat",
    ],
    check_elf=True,
    add_firmware_proprietary_file=True,
)

if __name__ == "__main__":
    ExtractUtils.device(module).run()
