#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
SOURCE_DIR="$PROJECT_DIR/lineage-build/source"

mkdir -p "$SOURCE_DIR"

docker build \
    --platform linux/amd64 \
    -t t65max-lineage-builder:23.2 \
    "$PROJECT_DIR/lineage/docker"

exec docker run --rm \
    --platform linux/amd64 \
    --name t65max-lineage-build \
    -e SYNC_JOBS=4 \
    -e BUILD_JOBS=8 \
    -v "$PROJECT_DIR:/project" \
    -v "$SOURCE_DIR:/src" \
    t65max-lineage-builder:23.2 \
    /project/lineage/docker/sync-and-build.sh
