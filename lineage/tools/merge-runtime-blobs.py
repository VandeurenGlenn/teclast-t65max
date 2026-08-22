#!/usr/bin/env python3
"""Merge stock runtime-observed vendor blobs into proprietary-files.txt."""

from __future__ import annotations

import argparse
from pathlib import Path


BEGIN = "# BEGIN: runtime-observed A8D4 blobs"
END = "# END: runtime-observed A8D4 blobs"


def source_path(line: str) -> str | None:
    line = line.strip()
    if not line or line.startswith("#"):
        return None
    line = line.lstrip("-")
    return line.split(";", 1)[0].split(":", 1)[0].removeprefix("/")


def runtime_paths(path: Path) -> set[str]:
    in_mappings = False
    result: set[str] = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        if line == "VENDOR_AND_ODM_MAPPINGS":
            in_mappings = True
            continue
        if not in_mappings or not line.startswith("/"):
            continue
        item = line.removeprefix("/")
        if item.startswith(("vendor/", "odm/")):
            result.add(item)
    return result


def strip_generated_block(lines: list[str]) -> list[str]:
    output: list[str] = []
    skipping = False
    for line in lines:
        if line == BEGIN:
            skipping = True
            continue
        if line == END:
            skipping = False
            continue
        if not skipping:
            output.append(line)
    return output


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--proprietary", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()

    original = strip_generated_block(
        args.proprietary.read_text(encoding="utf-8").splitlines()
    )
    selected = {item for line in original if (item := source_path(line))}
    observed = runtime_paths(args.runtime)
    additions = sorted(observed - selected)

    report_header = [
        "# A8D4 files observed in live process mappings but absent from the",
        "# original MT6789 reference-derived seed. Generated from the rooted",
        "# stock runtime; do not hand-edit.",
        f"# observed={len(observed)} already_selected={len(observed & selected)} additions={len(additions)}",
        "",
    ]
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text("\n".join(report_header + additions) + "\n", encoding="utf-8")

    while original and not original[-1]:
        original.pop()
    generated = [
        "",
        BEGIN,
        "# Generated from file-backed mappings on the rooted A8D4 Android 15",
        "# baseline. This is runtime evidence, not a complete dependency closure.",
        *additions,
        END,
    ]
    args.proprietary.write_text("\n".join(original + generated) + "\n", encoding="utf-8")

    print(
        f"observed={len(observed)} selected={len(observed & selected)} "
        f"added={len(additions)} total={len(selected | observed)}"
    )


if __name__ == "__main__":
    main()
