#!/bin/sh
set -eu

PROFILE=${COLIMA_PROFILE:-lineage-fast}
EXTERNAL_VOLUME=${T65MAX_BUILD_VOLUME:-/Volumes/LineageBuild}
MAX_FILES=${T65MAX_MAX_FILES:-1048576}
MAX_FILES_PER_PROCESS=${T65MAX_MAX_FILES_PER_PROCESS:-524288}

if [ ! -d "$EXTERNAL_VOLUME/t65max/source" ]; then
    echo "External Lineage source is unavailable: $EXTERNAL_VOLUME/t65max/source" >&2
    exit 2
fi

docker context use "colima-$PROFILE" >/dev/null 2>&1 || true
running=$(docker ps -q 2>/dev/null || true)
if [ -n "$running" ]; then
    echo "Colima optimization postponed: a container is still running." >&2
    exit 3
fi

if [ "$(uname -s)" = Darwin ]; then
    current_max=$(sysctl -n kern.maxfiles)
    current_per_process=$(sysctl -n kern.maxfilesperproc)
    if [ "$current_max" -lt "$MAX_FILES" ] || \
       [ "$current_per_process" -lt "$MAX_FILES_PER_PROCESS" ]; then
        echo "Administrator access is required once to raise macOS file limits."
        sudo sysctl -w "kern.maxfiles=$MAX_FILES"
        sudo sysctl -w "kern.maxfilesperproc=$MAX_FILES_PER_PROCESS"
    fi
    ulimit -n "$MAX_FILES_PER_PROCESS"
fi

colima stop --profile "$PROFILE" >/dev/null 2>&1 || true
colima start --profile "$PROFILE" \
    --cpu 6 \
    --memory 16 \
    --disk 100 \
    --mount-type virtiofs \
    --mount "$EXTERNAL_VOLUME:w"

if ! colima status --profile "$PROFILE" 2>&1 | grep -q 'mountType: virtiofs'; then
    echo "Colima $PROFILE did not activate VirtioFS." >&2
    exit 4
fi

echo "Colima $PROFILE configured: 6 CPUs, 16 GiB RAM, VirtioFS."
