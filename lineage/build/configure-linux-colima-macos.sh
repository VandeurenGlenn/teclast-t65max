#!/bin/sh
set -eu

EXTERNAL_VOLUME=${T65MAX_BUILD_VOLUME:-/Volumes/LineageBuild}
PROFILE=${COLIMA_PROFILE:-lineage-linux}
export COLIMA_HOME=${T65MAX_COLIMA_HOME:-$EXTERNAL_VOLUME/t65max/colima-linux-home}
OUT_DISK_NAME=${T65MAX_OUT_DISK_NAME:-t65max-out}
OUT_DISK_HOME=${T65MAX_OUT_DISK_HOME:-${HOME:?}/Library/Application Support/T65MaxLineage/lima}

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
    --cpus 10 \
    --memory 18 \
    --disk 220 \
    --root-disk 20 \
    --vm-type vz \
    --vz-rosetta \
    --mount none \
    --mount-type sshfs

# Colima manages its own external data disk, while the large incremental out/
# tree lives on a separate Lima disk backed by the faster internal SSD. Colima
# may regenerate lima.yaml during reconfiguration, so restore this attachment
# idempotently when the disk already exists.
out_disk_source="$OUT_DISK_HOME/_disks/$OUT_DISK_NAME"
lima_home="$COLIMA_HOME/_lima"
out_disk_link="$lima_home/_disks/$OUT_DISK_NAME"
lima_yaml="$lima_home/colima-$PROFILE/lima.yaml"

if [ -d "$out_disk_source" ]; then
    if [ -L "$out_disk_link" ]; then
        if [ "$(readlink "$out_disk_link")" != "$out_disk_source" ]; then
            echo "Unexpected Lima disk link: $out_disk_link" >&2
            exit 4
        fi
    elif [ -e "$out_disk_link" ]; then
        echo "Refusing to replace existing Lima disk path: $out_disk_link" >&2
        exit 4
    else
        ln -s "$out_disk_source" "$out_disk_link"
    fi
    if ! grep -Fq -- "- name: $OUT_DISK_NAME" "$lima_yaml"; then
        colima stop --profile "$PROFILE"
        LIMA_HOME="$lima_home" limactl edit "colima-$PROFILE" \
            --set ".additionalDisks += [{\"name\":\"$OUT_DISK_NAME\",\"format\":true,\"fsType\":\"ext4\"}]" \
            --tty=false
        LIMA_HOME="$lima_home" limactl start "colima-$PROFILE" --tty=false
    fi
fi

docker context use "colima-$PROFILE" >/dev/null
echo "Colima $PROFILE configured: 10 CPUs, 18 GiB RAM, native Linux storage, no host mounts."
