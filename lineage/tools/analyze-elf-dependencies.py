#!/usr/bin/env python3
"""Find stock vendor ELF dependencies absent from proprietary-files.txt."""

from __future__ import annotations

import argparse
import re
import subprocess
from collections import defaultdict
from pathlib import Path


NEEDED_RE = re.compile(r"^\s+NEEDED\s+(\S+)", re.MULTILINE)
BEGIN = "# BEGIN: ELF dependency closure"
END = "# END: ELF dependency closure"


def source_path(line: str) -> str | None:
    line = line.strip()
    if not line or line.startswith("#"):
        return None
    line = line.lstrip("-")
    return line.split(";", 1)[0].split(":", 1)[0].removeprefix("/")


def read_paths(path: Path) -> set[str]:
    return {
        item
        for line in path.read_text(encoding="utf-8").splitlines()
        if (item := source_path(line))
    }


def elf_class(path: Path) -> int | None:
    try:
        header = path.read_bytes()[:5]
    except OSError:
        return None
    if header[:4] != b"\x7fELF" or header[4] not in (1, 2):
        return None
    return 32 if header[4] == 1 else 64


def path_class(path: str) -> int | None:
    if "/lib64/" in f"/{path}":
        return 64
    if "/lib/" in f"/{path}":
        return 32
    return None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--proprietary", type=Path, required=True)
    parser.add_argument("--inventory", type=Path, action="append", required=True)
    parser.add_argument("--blob-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--objdump", default="objdump")
    parser.add_argument("--merge", action="store_true")
    args = parser.parse_args()

    selected = read_paths(args.proprietary)
    inventory: set[str] = set()
    for inventory_path in args.inventory:
        inventory.update(read_paths(inventory_path))
    inventory_by_name: dict[tuple[int, str], list[str]] = defaultdict(list)
    for item in inventory:
        if (bits := path_class(item)) is not None:
            inventory_by_name[(bits, Path(item).name)].append(item)

    selected_sonames: set[tuple[int, str]] = set()
    elfs: list[tuple[str, Path, int]] = []
    for item in sorted(selected):
        local = args.blob_root / item
        if (bits := elf_class(local)) is None:
            continue
        elfs.append((item, local, bits))
        selected_sonames.add((bits, Path(item).name))

    required_by: dict[tuple[int, str], set[str]] = defaultdict(set)
    failures: list[str] = []
    for item, local, bits in elfs:
        result = subprocess.run(
            [args.objdump, "-p", str(local)],
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode:
            failures.append(item)
            continue
        for soname in NEEDED_RE.findall(result.stdout):
            required_by[(bits, soname)].add(item)

    candidates: dict[str, set[str]] = defaultdict(set)
    ambiguous: dict[tuple[int, str], list[str]] = {}
    external: set[tuple[int, str]] = set()
    for key, consumers in required_by.items():
        if key in selected_sonames:
            continue
        stock = sorted(inventory_by_name.get(key, []))
        if len(stock) == 1:
            candidates[stock[0]].update(consumers)
        elif stock:
            ambiguous[key] = stock
        else:
            external.add(key)

    lines = [
        "# A8D4 proprietary ELF dependency analysis",
        "# Generated from selected local blobs and rooted stock partition inventories.",
        f"# elf_files={len(elfs)} needed_sonames={len(required_by)}",
        f"# unambiguous_stock_additions={len(candidates)} ambiguous_sonames={len(ambiguous)} external_sonames={len(external)} objdump_failures={len(failures)}",
        "",
        "# Unambiguous stock additions",
    ]
    for candidate in sorted(candidates):
        lines.append(candidate)

    lines.extend(["", "# Ambiguous stock resolutions"])
    for (bits, soname), paths in sorted(ambiguous.items()):
        lines.append(f"# {bits}-bit {soname}")
        lines.extend(f"#   {path}" for path in paths)

    lines.extend(["", "# External/system/APEX dependencies (informational)"])
    lines.extend(f"# {bits}-bit {soname}" for bits, soname in sorted(external))

    lines.extend(["", "# objdump failures"])
    lines.extend(f"# {item}" for item in failures)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines) + "\n", encoding="utf-8")

    if args.merge and candidates:
        proprietary_lines = args.proprietary.read_text(encoding="utf-8").splitlines()
        additions = sorted(candidates)
        if END in proprietary_lines:
            index = proprietary_lines.index(END)
            proprietary_lines[index:index] = additions
        else:
            while proprietary_lines and not proprietary_lines[-1]:
                proprietary_lines.pop()
            proprietary_lines.extend(
                [
                    "",
                    BEGIN,
                    "# Unambiguous stock paths required by DT_NEEDED entries.",
                    *additions,
                    END,
                ]
            )
        args.proprietary.write_text(
            "\n".join(proprietary_lines) + "\n", encoding="utf-8"
        )

    print(
        f"elfs={len(elfs)} additions={len(candidates)} "
        f"ambiguous={len(ambiguous)} external={len(external)} failures={len(failures)}"
        f" merged={'yes' if args.merge and candidates else 'no'}"
    )


if __name__ == "__main__":
    main()
