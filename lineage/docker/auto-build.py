#!/usr/bin/env python3
"""Run the T65 Max conflict-fixing build loop in one Docker container."""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-rounds", type=int, default=50)
    parser.add_argument("--jobs", type=int, default=6)
    parser.add_argument("--go-memory-limit", default="16GiB")
    parser.add_argument("--go-gc", type=int, default=50)
    args = parser.parse_args()

    project = Path(__file__).resolve().parents[2]
    source = project / "lineage-build" / "source"
    command = [
        "docker", "run", "--rm", "--platform", "linux/amd64",
        "--name", "t65max-lineage-auto-build",
        "--ulimit", "nofile=1048576:1048576",
        "-e", f"BUILD_JOBS={args.jobs}",
        "-e", f"MAX_ROUNDS={args.max_rounds}",
        "-e", f"GOMEMLIMIT={args.go_memory_limit}",
        "-e", f"GOGC={args.go_gc}",
        "-v", f"{project}:/project",
        "-v", f"{source}:/src",
        "-v", "t65max-lineage-out:/src/out",
        "t65max-lineage-builder:23.2",
        "/project/lineage/docker/auto-build-inner.sh",
    ]
    return subprocess.run(command, check=False).returncode

if __name__ == "__main__":
    raise SystemExit(main())
