#!/bin/sh
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
cd "$PROJECT_DIR"
exec ./lineage/build/migrate-to-linux-colima-macos.sh
