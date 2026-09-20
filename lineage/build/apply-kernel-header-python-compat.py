#!/usr/bin/env python3

import argparse
from pathlib import Path


OLD = "./bionic/libc/kernel/tools/clean_header.py -u \\\n"
NEW = "\"${KERNEL_HEADER_PYTHON:-prebuilts/clang/host/linux-x86/clang-r563880c/python3/bin/python3}\" \\\n    ./bionic/libc/kernel/tools/clean_header.py -u \\\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    args = parser.parse_args()
    path = args.source / "vendor/lineage/tools/clean_headers.sh"
    text = path.read_text()
    if NEW in text:
        print("kernel header Python compatibility already applied")
        return
    if OLD not in text:
        raise SystemExit(f"unexpected clean_headers.sh content: {path}")
    path.write_text(text.replace(OLD, NEW, 1))
    print(f"patched {path}")


if __name__ == "__main__":
    main()
