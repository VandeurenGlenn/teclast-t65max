#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)

# Conservative defaults for a 24 GiB Apple Silicon Mac. Override when needed.
: "${T65MAX_BUILD_JOBS:=3}"
: "${T65MAX_SWAP_GIB:=8}"
: "${T65MAX_GO_MEMORY_LIMIT:=16GiB}"
: "${T65MAX_GO_GC:=50}"
: "${T65MAX_CCACHE_SIZE:=12G}"

BUILD_VOLUME=${T65MAX_BUILD_VOLUME:-/Volumes/LineageBuild}
free_kib=$(df -Pk "$BUILD_VOLUME" | awk 'NR == 2 {print $4}')
minimum_kib=$((60 * 1024 * 1024))
if [ "$free_kib" -lt "$minimum_kib" ]; then
    free_gib=$((free_kib / 1024 / 1024))
    echo "Full build not started: only ${free_gib} GiB free; at least 60 GiB is required." >&2
    echo "Preserve the source and current out cache, then reclaim storage first." >&2
    exit 4
fi

exec env \
    T65MAX_SWAP_GIB="$T65MAX_SWAP_GIB" \
    T65MAX_GO_MEMORY_LIMIT="$T65MAX_GO_MEMORY_LIMIT" \
    T65MAX_GO_GC="$T65MAX_GO_GC" \
    "$PROJECT_DIR/lineage/build/run-auto-build-linux-macos.sh" \
    --target bacon \
    --jobs "$T65MAX_BUILD_JOBS" \
    --ccache-size "$T65MAX_CCACHE_SIZE" \
    "$@"
