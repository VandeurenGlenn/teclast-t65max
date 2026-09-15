#!/usr/bin/env python3
"""Provide the legacy Rust bindgen Clang path from the installed toolchain."""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    args = parser.parse_args()

    clang_root = args.source / "prebuilts/clang/host/linux-x86"
    current = clang_root / "clang-r563880c"
    legacy = clang_root / "clang-r563880"

    if not (current / "bin/clang").exists() or not (current / "lib/libclang.so").exists():
        raise SystemExit(f"required clang-r563880c toolchain is incomplete: {current}")
    if legacy.is_symlink():
        if legacy.resolve() != current.resolve():
            raise SystemExit(f"unexpected legacy Clang symlink: {legacy} -> {legacy.readlink()}")
        return 0
    if legacy.exists():
        raise SystemExit(f"refusing to replace existing legacy Clang path: {legacy}")

    legacy.symlink_to(current.name, target_is_directory=True)
    print(f"provided Rust bindgen compatibility path: {legacy} -> {current.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
