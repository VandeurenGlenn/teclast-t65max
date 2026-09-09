#!/usr/bin/env python3
"""Apply narrow source fixes needed on a case-insensitive macOS bind mount."""

from __future__ import annotations

import argparse
from pathlib import Path


def exact_child(directory: Path, name: str) -> Path | None:
    return next((entry for entry in directory.iterdir() if entry.name == name), None)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    args = parser.parse_args()

    root = args.source / "system/libvintf"
    include_dir = root / "include/vintf"
    old_header = exact_child(include_dir, "Regex.h")
    new_header = exact_child(include_dir, "PosixRegex.h")

    # The build has -I.../include/vintf. On case-insensitive APFS, <regex.h>
    # therefore resolves to libvintf's Regex.h instead of Bionic's regex.h.
    if old_header is not None:
        if new_header is not None:
            raise RuntimeError("both Regex.h and PosixRegex.h exist")
        text = old_header.read_text()
        if "#include <regex.h>" not in text:
            raise RuntimeError("unexpected system/libvintf Regex.h contents")
        text = text.replace("ANDROID_VINTF_REGEX_H_", "ANDROID_VINTF_POSIX_REGEX_H_")
        old_header.rename(include_dir / "PosixRegex.h")
        (include_dir / "PosixRegex.h").write_text(text)
        print("renamed system/libvintf Regex.h to avoid macOS case-fold collision")
    elif new_header is None:
        # A case-sensitive checkout does not need the workaround.
        print("case-fold workaround not needed")
        return 0

    for path in root.rglob("*"):
        if path.suffix not in {".h", ".cpp"} or not path.is_file():
            continue
        text = path.read_text()
        updated = text.replace('#include "Regex.h"', '#include "PosixRegex.h"')
        if updated != text:
            path.write_text(updated)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
