#!/usr/bin/env python3
"""Run the T65 Max conflict-fixing build loop in one Docker container."""

from __future__ import annotations

import argparse
import os
import subprocess
from pathlib import Path

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-rounds", type=int, default=50)
    parser.add_argument("--jobs", type=int, default=3)
    parser.add_argument("--go-memory-limit", default="16GiB")
    parser.add_argument("--go-gc", type=int, default=50)
    parser.add_argument("--target", default="vendorbootimage")
    parser.add_argument("--ccache-size", default="6G")
    args = parser.parse_args()

    project = Path(__file__).resolve().parents[2]
    native_project = os.environ.get("T65MAX_VM_NATIVE_PROJECT")
    native_source = os.environ.get("T65MAX_VM_NATIVE_SOURCE")
    if bool(native_project) != bool(native_source):
        parser.error("VM-native project and source paths must be supplied together")
    if native_project:
        runtime_project = native_project
        source = native_source
    else:
        runtime_project = str(Path(
            os.environ.get("T65MAX_RUNTIME_PROJECT", str(project))
        ).resolve(strict=True))
        # Docker/Colima cannot follow a host symlink whose target is outside
        # the automatically shared home directory. Bind the canonical path.
        source = str((project / "lineage-build" / "source").resolve(strict=True))
    command = [
        "docker", "run", "--rm", "--platform", "linux/amd64",
        "--name", f"t65max-lineage-build-{os.getpid()}",
        "--ulimit", "nofile=1048576:1048576",
        "-e", f"BUILD_JOBS={args.jobs}",
        "-e", f"MAX_ROUNDS={args.max_rounds}",
        "-e", f"GOMEMLIMIT={args.go_memory_limit}",
        "-e", f"GOGC={args.go_gc}",
        "-e", f"BUILD_TARGET={args.target}",
        "-e", f"CCACHE_MAX_SIZE={args.ccache_size}",
        "-e", "CCACHE_DIR=/src/out/.ccache",
        "-v", f"{runtime_project}:/project",
        "-v", f"{source}:/src",
        "-v", "t65max-lineage-out:/src/out",
    ]
    if native_project:
        command.extend(["--user", "501:1000", "-e", "HOME=/tmp"])
    command.extend([
        "t65max-lineage-builder:23.2",
        "/bin/bash",
        "/project/lineage/build/auto-build-inner.sh",
    ])
    return subprocess.run(command, check=False).returncode

if __name__ == "__main__":
    raise SystemExit(main())
