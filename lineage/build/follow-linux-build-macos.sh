#!/bin/sh
set -eu

REFRESH_SECONDS=60
SOONG_ESTIMATE_MINUTES=100
while [ "$#" -gt 0 ]; do
    case "$1" in
        -r|--refresh)
            [ "$#" -ge 2 ] || { echo "Missing value for $1" >&2; exit 2; }
            REFRESH_SECONDS=$2
            shift 2
            ;;
        --refresh=*)
            REFRESH_SECONDS=${1#*=}
            shift
            ;;
        -s|--soong-estimate)
            [ "$#" -ge 2 ] || { echo "Missing value for $1" >&2; exit 2; }
            SOONG_ESTIMATE_MINUTES=$2
            shift 2
            ;;
        --soong-estimate=*)
            SOONG_ESTIMATE_MINUTES=${1#*=}
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [-r|--refresh SECONDS] [-s|--soong-estimate MINUTES]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 2
            ;;
    esac
done

case "$REFRESH_SECONDS" in
    ''|*[!0-9]*) echo "Refresh interval must be a positive integer." >&2; exit 2 ;;
esac
[ "$REFRESH_SECONDS" -gt 0 ] || { echo "Refresh interval must be greater than zero." >&2; exit 2; }
case "$SOONG_ESTIMATE_MINUTES" in
    ''|*[!0-9]*) echo "Soong estimate must be a positive integer." >&2; exit 2 ;;
esac
[ "$SOONG_ESTIMATE_MINUTES" -gt 0 ] || { echo "Soong estimate must be greater than zero." >&2; exit 2; }

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
VM_HOME=$(ssh -F "$SSH_CONFIG" "$VM_HOST" 'printf %s "$HOME"')
REMOTE_BUILD_DIR="$VM_HOME/t65max/project/lineage/build"

ssh -F "$SSH_CONFIG" "$VM_HOST" "mkdir -p '$REMOTE_BUILD_DIR'"
rsync -a -e "ssh -F $SSH_CONFIG" \
    "$PROJECT_DIR/lineage/build/record-build-times-linux.sh" "$VM_HOST:$REMOTE_BUILD_DIR/"
ssh -F "$SSH_CONFIG" "$VM_HOST" \
    "nohup env VM_ROOT='$VM_HOME/t65max' bash '$REMOTE_BUILD_DIR/record-build-times-linux.sh' </dev/null >'$VM_HOME/t65max/project/lineage-build/logs/timing-recorder.log' 2>&1 &"

ssh -T -F "$SSH_CONFIG" "$VM_HOST" \
    "VM_ROOT='$VM_HOME/t65max' bash -s -- '$REFRESH_SECONDS' '$SOONG_ESTIMATE_MINUTES'" <<'REMOTE'
set -u

refresh_seconds=$1
soong_estimate_seconds=$(($2 * 60))
log_dir="$VM_ROOT/project/lineage-build/logs/auto-build-single"
term_columns=$(tput cols 2>/dev/null || echo 120)
trap 'printf "\n"; exit 130' INT TERM
echo "LineageOS build monitor"
echo "Ctrl-C sluit alleen deze monitor."

while :; do
    log=$(ls -1t "$log_dir"/round-*.log 2>/dev/null | head -1)
    build_pid=$(pgrep -o -f '[a]uto-build-inner.sh' || true)
    soong_pid=$(pgrep -o -x soong_build || true)
    ninja_pid=$(pgrep -o -f '[n]inja .*out/combined-lineage_t65max\.ninja' || true)
    progress=""
    estimate_compact=""

    if [ -n "$build_pid" ]; then
        elapsed=$(ps -p "$build_pid" -o etime= | tr -d ' ')
        status_compact="Actief $elapsed"
    else
        status_compact="Gestopt"
    fi

    if [ -n "${log:-}" ]; then
        progress=$(tail -n 4000 "$log" | tr '\r' '\n' | grep -E '\[[[:space:]]*[0-9]+%[[:space:]]+[0-9]+/[0-9]+\]' | tail -1 || true)
        if [ -n "$soong_pid" ]; then
            phase_compact="Soong"
        elif [ -n "$progress" ]; then
            phase_compact=$(printf '%s\n' "$progress" | sed -nE \
                's/.*\[[[:space:]]*([0-9]+%[[:space:]]+[0-9]+\/[0-9]+)\].*/\1/p')
        else
            phase_compact="wachten op loguitvoer"
        fi
    else
        phase_compact="nog geen log"
    fi

    if [ -n "$soong_pid" ]; then
        soong_elapsed=$(ps -p "$soong_pid" -o etimes= | tr -d ' ')
        if [ -n "$soong_elapsed" ] && [ "$soong_elapsed" -lt "$soong_estimate_seconds" ]; then
            remaining=$((soong_estimate_seconds - soong_elapsed))
            eta=$(date -d "@$(( $(date +%s) + remaining ))" '+%H:%M')
            estimate_compact="ETA ~$(((remaining + 59) / 60))m ($eta)"
        elif [ -n "$soong_elapsed" ]; then
            estimate_compact="schatting +$(((soong_elapsed - soong_estimate_seconds) / 60))m overschreden"
        fi
    elif [ -n "${progress:-}" ] && [ -n "$ninja_pid" ]; then
        completed=$(printf '%s\n' "$progress" | sed -nE \
            's/.*\[[[:space:]]*[0-9]+%[[:space:]]+([0-9]+)\/([0-9]+)\].*/\1/p')
        total=$(printf '%s\n' "$progress" | sed -nE \
            's/.*\[[[:space:]]*[0-9]+%[[:space:]]+([0-9]+)\/([0-9]+)\].*/\2/p')
        ninja_elapsed=$(ps -p "$ninja_pid" -o etimes= | tr -d ' ')
        # Small totals belong to Soong/Kati bootstrap stages, not the actual
        # Android compilation. Their task weights are too uneven for an ETA.
        if [ -n "$completed" ] && [ -n "$total" ] && [ -n "$ninja_elapsed" ] \
            && [ "$total" -ge 1000 ] && [ "$completed" -gt 0 ]; then
            if [ "$ninja_elapsed" -lt 600 ] || [ $((completed * 100)) -lt "$total" ]; then
                estimate_compact="ETA stabiliseert"
            else
                remaining=$((ninja_elapsed * (total - completed) / completed))
                remaining_minutes=$(((remaining + 59) / 60))
                eta=$(date -d "@$(( $(date +%s) + remaining ))" '+%H:%M')
                if [ "$remaining_minutes" -ge 60 ]; then
                    remaining_text="$((remaining_minutes / 60))u $((remaining_minutes % 60))m"
                else
                    remaining_text="${remaining_minutes}m"
                fi
                estimate_compact="ETA ~$remaining_text ($eta)"
            fi
        fi
    fi

    free_output=$(free -h)
    ram_compact=$(printf '%s\n' "$free_output" | awk 'NR == 2 {print $3 "/" $2}')
    swap_compact=$(printf '%s\n' "$free_output" | awk 'NR == 3 {print $3 "/" $2}')
    storage_compact=$(df -h "$VM_ROOT" | awk 'NR == 2 {print $4}')
    status="$status_compact | $phase_compact"
    [ -n "$estimate_compact" ] && status="$status | $estimate_compact"
    status="$status | RAM $ram_compact | swap $swap_compact | vrij $storage_compact"
    printf '\r\033[2K%s' "${status:0:term_columns}"

    if [ -z "$build_pid" ]; then
        echo
        [ -n "${log:-}" ] && tail -n 20 "$log"
        exit 0
    fi
    sleep "$refresh_seconds"
done
REMOTE

mkdir -p "$PROJECT_DIR/lineage-build/logs/auto-build-single"
rsync -a -e "ssh -F $SSH_CONFIG" \
    "$VM_HOST:$VM_HOME/t65max/project/lineage-build/logs/auto-build-single/" \
    "$PROJECT_DIR/lineage-build/logs/auto-build-single/" 2>/dev/null || true
