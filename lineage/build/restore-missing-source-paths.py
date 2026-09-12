#!/usr/bin/env python3
"""Restore only Git-tracked source paths that Soong explicitly reports missing."""

from __future__ import annotations

import argparse
import re
import subprocess
from pathlib import Path


MISSING_RE = re.compile(r'module source path "(?P<path>[^"]+)" does not exist')


def git(repo: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    args = parser.parse_args()

    source = args.source.resolve()
    paths = sorted(set(MISSING_RE.findall(args.log.read_text(errors="replace"))))
    if not paths:
        return 10

    for relative_text in paths:
        relative = Path(relative_text)
        if relative.is_absolute() or ".." in relative.parts:
            print(f"refusing unsafe missing path: {relative_text}")
            return 11

        target = source / relative
        repo = target.parent
        while repo != source and not (repo / ".git").exists():
            repo = repo.parent
        if not (repo / ".git").exists():
            print(f"no owning Git repository for: {relative_text}")
            return 12

        repo_relative = target.relative_to(repo).as_posix()
        tracked = git(repo, "ls-files", "--error-unmatch", "--", repo_relative)
        if tracked.returncode != 0:
            print(f"missing path is not tracked; refusing to invent it: {relative_text}")
            return 13

        restored = git(repo, "restore", "--source=HEAD", "--worktree", "--", repo_relative)
        if restored.returncode != 0 or not (target.exists() or target.is_symlink()):
            print(f"failed to restore tracked source path: {relative_text}")
            return 14
        print(f"restored tracked source path: {relative_text}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
