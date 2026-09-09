#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
SOURCE_DIR="$PROJECT_DIR/lineage-build/source"

mkdir -p "$SOURCE_DIR"

docker build \
    --platform linux/arm64 \
    -f "$PROJECT_DIR/lineage/docker/Dockerfile.sync" \
    -t t65max-lineage-sync:23.2 \
    "$PROJECT_DIR/lineage/docker"

docker run --rm \
    --platform linux/arm64 \
    --name t65max-lineage-sync \
    --ulimit nofile=1048576:1048576 \
    -e SYNC_JOBS=1 \
    -v "$PROJECT_DIR:/project" \
    -v "$SOURCE_DIR:/src" \
    t65max-lineage-sync:23.2 \
    /project/lineage/docker/sync-source.sh

docker build \
    --platform linux/amd64 \
    -t t65max-lineage-builder:23.2 \
    "$PROJECT_DIR/lineage/docker"

exec docker run --rm \
    --platform linux/amd64 \
    --name t65max-lineage-build \
    --ulimit nofile=1048576:1048576 \
    -e BUILD_JOBS=8 \
    -v "$PROJECT_DIR:/project" \
    -v "$SOURCE_DIR:/src" \
    t65max-lineage-builder:23.2 \
    /project/lineage/docker/build-only.sh
