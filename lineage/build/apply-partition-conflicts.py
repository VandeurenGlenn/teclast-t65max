#!/usr/bin/env python3
"""Apply only exact Soong 'partition is different' blob fixes."""

from __future__ import annotations

import argparse
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

CONFLICT_RE = re.compile(
    r'module "(?P<module>[^"]+)".*partition is different:', re.MULTILINE
)

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--blob-list", type=Path, required=True)
    parser.add_argument("--audit-log", type=Path, required=True)
    parser.add_argument("--round", required=True)
    args = parser.parse_args()

    modules = sorted(set(CONFLICT_RE.findall(args.log.read_text(errors="replace"))))
    if not modules:
        return 10

    lines = args.blob_list.read_text().splitlines(keepends=True)
    changes: list[tuple[str, str]] = []
    for module in modules:
        filename = f"{module}.so"
        matches: list[int] = []
        for index, line in enumerate(lines):
            entry = line.strip()
            if not entry or entry.startswith("#"):
                continue
            path = entry.split(";", 1)[0].lstrip("-")
            if Path(path).name == filename:
                matches.append(index)

        pending = [index for index in matches if "MAKE_COPY_RULE_ONLY" not in lines[index]]
        if not matches or not pending:
            print(f"cannot safely map conflict module: {module}", file=sys.stderr)
            return 11

        for index in pending:
            newline = "\n" if lines[index].endswith("\n") else ""
            original = lines[index].rstrip("\n")
            lines[index] = f"{original};MAKE_COPY_RULE_ONLY{newline}"
            changes.append((module, original.split(";", 1)[0].lstrip("-")))

    args.blob_list.write_text("".join(lines))
    args.audit_log.parent.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now(timezone.utc).isoformat()
    with args.audit_log.open("a") as audit:
        for module, path in changes:
            audit.write(f"{timestamp}\t{args.round}\t{module}\t{path}\n")
    print("copy-only: " + ", ".join(modules), flush=True)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
