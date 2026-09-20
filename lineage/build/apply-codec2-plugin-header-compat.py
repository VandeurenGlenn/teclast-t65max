#!/usr/bin/env python3
"""Remove the obsolete Codec2 header workaround from an existing checkout.

The real incompatibility was the retained stock libcodec2_hidl_plugin, which
shadowed the source module without exporting its headers or newer symbols.
The proprietary list now excludes that blob, so upstream's normal shared-lib
dependency supplies both the implementation and its exported headers.
"""

import argparse
from pathlib import Path


MODULES = (
    ("media/codec2/hal/hidl/1.0/utils/Android.bp", "libcodec2_hidl@1.0"),
    ("media/codec2/hal/hidl/1.1/utils/Android.bp", "libcodec2_hidl@1.1"),
    ("media/codec2/hal/hidl/1.2/utils/Android.bp", "libcodec2_hidl@1.2"),
    ("media/codec2/hal/aidl/Android.bp", "libcodec2_aidl"),
)


def remove_header_dependency(path: Path, module: str) -> bool:
    text = path.read_text()
    module_start = text.index(f'name: "{module}"')
    headers_start = text.index("    header_libs: [", module_start)
    dependency = '        "libcodec2_hidl_plugin_headers",\n'
    headers_end = text.index("    ],", headers_start)
    block = text[headers_start:headers_end]
    if dependency not in block:
        return False
    path.write_text(text[:headers_start] + block.replace(dependency, "") + text[headers_end:])
    return True


def restore_header_module(path: Path) -> bool:
    text = path.read_text()
    module_start = text.index('name: "libcodec2_hidl_plugin_headers"')
    module_end = text.index("\n}\n", module_start)
    module = text[module_start:module_end]
    properties = (
        '    min_sdk_version: "29",\n'
        "    apex_available: [\n"
        '        "//apex_available:platform",\n'
        '        "com.android.media.swcodec",\n'
        '        "test_com.android.media.swcodec",\n'
        "    ],\n"
    )
    restored = module.replace(properties, "").replace('        "internal",\n', "")
    if restored == module:
        return False
    path.write_text(text[:module_start] + restored + text[module_end:])
    return True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    args = parser.parse_args()

    frameworks_av = args.source / "frameworks/av"
    changed = restore_header_module(
        frameworks_av / "media/codec2/hal/plugin/Android.bp"
    )
    for relative, module in MODULES:
        changed |= remove_header_dependency(frameworks_av / relative, module)
    print("removed obsolete Codec2 plugin header workaround" if changed
          else "Codec2 plugin sources already match upstream")


if __name__ == "__main__":
    main()
