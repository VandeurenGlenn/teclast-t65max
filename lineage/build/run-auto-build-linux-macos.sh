#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
EXTERNAL_VOLUME=${T65MAX_BUILD_VOLUME:-/Volumes/LineageBuild}
PROFILE=${COLIMA_PROFILE:-lineage-linux}
export COLIMA_HOME=${T65MAX_COLIMA_HOME:-$EXTERNAL_VOLUME/t65max/colima-linux-home}
SSH_CONFIG="$COLIMA_HOME/ssh_config"
VM_HOST="colima-$PROFILE"
if [ ! -s "$SSH_CONFIG" ]; then
    SSH_CONFIG="$COLIMA_HOME/_lima/colima-$PROFILE/ssh.config"
    VM_HOST="lima-colima-$PROFILE"
fi
VM_DATA_ROOT=/var/lib/docker/t65max
VM_OUT_ROOT=/mnt/lima-t65max-out/out
SWAP_GIB=${T65MAX_SWAP_GIB:-12}
# Keep build swap on the otherwise mostly empty VM root disk. This preserves
# the native data disk's limited free space for out/ and ccache.
SWAP_PATH=/.t65max-build.swap
GO_MEMORY_LIMIT=${T65MAX_GO_MEMORY_LIMIT:-16GiB}
GO_GC=${T65MAX_GO_GC:-50}
GO_MAX_PROCS=${T65MAX_GO_MAX_PROCS:-6}
BUILD_TARGET=vendorbootimage
BUILD_JOBS=${T65MAX_BUILD_JOBS:-3}
MAX_ROUNDS=${T65MAX_MAX_ROUNDS:-50}
CCACHE_SIZE=${T65MAX_CCACHE_SIZE:-6G}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --target) BUILD_TARGET=$2; shift 2 ;;
        --jobs) BUILD_JOBS=$2; shift 2 ;;
        --max-rounds) MAX_ROUNDS=$2; shift 2 ;;
        --ccache-size) CCACHE_SIZE=$2; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

if [ ! -s "$SSH_CONFIG" ] || ! ssh -F "$SSH_CONFIG" "$VM_HOST" true >/dev/null 2>&1; then
    echo "Linux build VM is stopped. Run ./lineage/build/configure-linux-colima-macos.sh first." >&2
    exit 5
fi

VM_HOME=$(ssh -F "$SSH_CONFIG" "$VM_HOST" 'printf %s "$HOME"')
VM_ROOT="$VM_HOME/t65max"

ssh -F "$SSH_CONFIG" "$VM_HOST" \
    "sudo mkdir -p '$VM_DATA_ROOT' && sudo chown -R \$(id -u):\$(id -g) '$VM_DATA_ROOT' && mkdir -p '$VM_ROOT' && (mountpoint -q '$VM_ROOT' || sudo mount --bind '$VM_DATA_ROOT' '$VM_ROOT')"

if ! ssh -F "$SSH_CONFIG" "$VM_HOST" test -f "$VM_ROOT/source/build/envsetup.sh"; then
    echo "VM-native source is unavailable. Run ./lineage/build/migrate-to-linux-colima-macos.sh first." >&2
    exit 6
fi

if ! ssh -F "$SSH_CONFIG" "$VM_HOST" \
    "test -d '$VM_OUT_ROOT' && test \"\$(readlink -f '$VM_ROOT/source/out')\" = '$VM_OUT_ROOT'"; then
    echo "Internal ext4 out disk is not mounted at $VM_OUT_ROOT; build not started." >&2
    echo "Reattach the t65max-out Lima disk before continuing." >&2
    exit 9
fi

if ! ssh -F "$SSH_CONFIG" "$VM_HOST" 'test -x /lib64/ld-linux-x86-64.so.2 && command -v ccache >/dev/null && command -v java >/dev/null && command -v xxd >/dev/null'; then
    echo "Linux build tools are unavailable. Run ./lineage/build/provision-direct-linux-build-macos.sh first." >&2
    exit 7
fi

ssh -F "$SSH_CONFIG" "$VM_HOST" "mkdir -p '$VM_ROOT/project/lineage' '$VM_ROOT/project/lineage-build/logs'"
rsync -a --delete -e "ssh -F $SSH_CONFIG" \
    "$PROJECT_DIR/lineage/" "$VM_HOST:$VM_ROOT/project/lineage/"

if ssh -F "$SSH_CONFIG" "$VM_HOST" pgrep -f '[a]uto-build-inner.sh' >/dev/null; then
    echo "A LineageOS build is already running in the VM." >&2
    echo "Follow it with: ./lineage/build/follow-linux-build-macos.sh" >&2
    exit 8
fi

# Keep the build swap active for the VM lifetime. A host-side SSH interruption
# does not guarantee that the remote Ninja process has stopped; running
# swapoff from an EXIT trap can therefore exhaust RAM and make the guest OOM
# killer terminate the still-running build. The next build reuses this file,
# and a VM restart deactivates it before the inactive file is recreated.
ssh -F "$SSH_CONFIG" "$VM_HOST" \
    "if sudo swapon --noheadings --show=NAME | grep -Fxq '$SWAP_PATH'; then echo 'reusing active build swap'; else sudo rm -f '$SWAP_PATH' && sudo fallocate -l '${SWAP_GIB}G' '$SWAP_PATH' && sudo chmod 600 '$SWAP_PATH' && sudo mkswap '$SWAP_PATH' >/dev/null && sudo swapon '$SWAP_PATH'; fi"

# Docker is not involved in the build. Stopping it also releases VM memory.
ssh -F "$SSH_CONFIG" "$VM_HOST" \
    "sudo systemctl stop docker.service docker.socket 2>/dev/null || true"

# Run outside the SSH session. A sleeping Mac, closed Terminal, lost cable or
# monitor disconnect must not send SIGHUP to Ninja and waste completed work.
REMOTE_LAUNCH_LOG="$VM_ROOT/project/lineage-build/logs/detached-build.log"
REMOTE_PID_FILE="$VM_ROOT/project/lineage-build/logs/detached-build.pid"
ssh -T -F "$SSH_CONFIG" "$VM_HOST" \
    "nohup setsid env SOURCE_DIR='$VM_ROOT/source' PROJECT_DIR='$VM_ROOT/project' BUILD_JOBS='$BUILD_JOBS' MAX_ROUNDS='$MAX_ROUNDS' GOMEMLIMIT='$GO_MEMORY_LIMIT' GOGC='$GO_GC' GOMAXPROCS='$GO_MAX_PROCS' BUILD_TARGET='$BUILD_TARGET' CCACHE_MAX_SIZE='$CCACHE_SIZE' bash '$VM_ROOT/project/lineage/build/auto-build-inner.sh' </dev/null >'$REMOTE_LAUNCH_LOG' 2>&1 & printf '%s\n' \$! >'$REMOTE_PID_FILE'"

echo "LineageOS build detached in the VM; SSH disconnects can no longer stop it."
echo "Follow it with: ./lineage/build/follow-linux-build-macos.sh"
