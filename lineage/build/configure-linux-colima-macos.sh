#!/bin/sh
set -eu

EXTERNAL_VOLUME=${T65MAX_BUILD_VOLUME:-/Volumes/LineageBuild}
PROFILE=${COLIMA_PROFILE:-lineage-linux}
export COLIMA_HOME=${T65MAX_COLIMA_HOME:-$EXTERNAL_VOLUME/t65max/colima-linux-home}

if [ ! -d "$EXTERNAL_VOLUME/t65max" ]; then
    echo "External Lineage volume is unavailable: $EXTERNAL_VOLUME" >&2
    exit 2
fi

mkdir -p "$COLIMA_HOME"

if colima status --profile "$PROFILE" >/dev/null 2>&1; then
    docker context use "colima-$PROFILE" >/dev/null 2>&1 || true
    if [ -n "$(docker ps -q 2>/dev/null || true)" ]; then
        echo "Configuration postponed: a container is still running." >&2
        exit 3
    fi
    colima stop --profile "$PROFILE"
fi

# No macOS directory is mounted. Android source and output live on the VM's
# native ext4 data disk, whose sparse backing file is stored on the external SSD.
colima start --profile "$PROFILE" \
    --cpus 6 \
    --memory 16 \
    --disk 220 \
    --root-disk 20 \
    --vm-type vz \
    --vz-rosetta \
    --mount none \
    --mount-type sshfs

docker context use "colima-$PROFILE" >/dev/null
echo "Colima $PROFILE configured: 6 CPUs, 16 GiB RAM, native Linux storage, no host mounts."
