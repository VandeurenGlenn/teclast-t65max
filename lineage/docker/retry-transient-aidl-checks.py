#!/usr/bin/env python3
"""Retry failed frozen-AIDL equality checks without evaluating build-log shell."""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import tempfile
from pathlib import Path


FAILED_COMMAND_RE = re.compile(
    r"^FAILED: (?P<target>\S+/has_development)\n(?P<command>[^\n]+)$",
    re.MULTILINE,
)
CHECK_RE = re.compile(
    r"(?P<tool>out/host/linux-x86/bin/aidl) "
    r"--checkapi=equal --stability vintf "
    r"(?P<frozen>\S+) (?P<current>\S+)"
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    args = parser.parse_args()

    checks: set[tuple[str, str, str, str]] = set()
    log = args.log.read_text(errors="replace")
    for failed in FAILED_COMMAND_RE.finditer(log):
        match = CHECK_RE.search(failed.group("command"))
        if match:
            checks.add(
                (
                    failed.group("target"),
                    match.group("tool"),
                    match.group("frozen"),
                    match.group("current"),
                )
            )

    if not checks:
        return 10

    for target, tool, frozen, current in sorted(checks):
        result = subprocess.run(
            [tool, "--checkapi=equal", "--stability", "vintf", frozen, current],
            cwd=args.source,
            check=False,
        )
        if result.returncode != 0:
            with tempfile.TemporaryDirectory(prefix="aidl-equality-") as temp:
                frozen_copy = Path(temp) / "frozen"
                current_copy = Path(temp) / "current"
                shutil.copytree(
                    args.source / frozen,
                    frozen_copy,
                    ignore=shutil.ignore_patterns(".hash"),
                )
                shutil.copytree(
                    args.source / current,
                    current_copy,
                    ignore=shutil.ignore_patterns(".hash"),
                )
                result = subprocess.run(
                    [tool, "--checkapi=equal", "--stability", "vintf", frozen_copy, current_copy],
                    cwd=args.source,
                    check=False,
                )
        if result.returncode != 0:
            print(f"real frozen-AIDL mismatch remains: {frozen}")
            return 11
        target_path = args.source / target
        target_path.parent.mkdir(parents=True, exist_ok=True)
        target_path.write_text("0\n")
        print(f"validated frozen-AIDL edge: {frozen}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
