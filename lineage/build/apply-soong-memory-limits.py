#!/usr/bin/env python3
"""Pass Go runtime memory controls into Soong's sanitized subprocess env."""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    args = parser.parse_args()

    path = args.source / "build/soong/ui/build/soong.go"
    text = path.read_text()
    marker = 'for _, name := range []string{"GOMEMLIMIT", "GOGC", "GOMAXPROCS"}'
    if marker in text:
        return 0

    legacy_marker = 'for _, name := range []string{"GOMEMLIMIT", "GOGC"}'
    if legacy_marker in text:
        path.write_text(text.replace(legacy_marker, marker, 1))
        print(f"enabled bounded Go heap and CPU limit for Soong subprocesses: {path}")
        return 0

    anchor = "\tinvocationEnv := make(map[string]string)\n"
    if text.count(anchor) != 1:
        raise SystemExit(f"unexpected Soong invocation environment layout: {path}")

    addition = anchor + (
        '\tfor _, name := range []string{"GOMEMLIMIT", "GOGC", "GOMAXPROCS"} {\n'
        "\t\tif value := os.Getenv(name); value != \"\" {\n"
        "\t\t\tinvocationEnv[name] = value\n"
        "\t\t}\n"
        "\t}\n"
    )
    path.write_text(text.replace(anchor, addition, 1))
    print(f"enabled bounded Go heap and CPU limit for Soong subprocesses: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
