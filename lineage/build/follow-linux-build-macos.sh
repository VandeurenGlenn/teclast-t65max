#!/bin/sh
set -eu

EXTERNAL_VOLUME=${T65MAX_BUILD_VOLUME:-/Volumes/LineageBuild}
PROFILE=${COLIMA_PROFILE:-lineage-linux}
export COLIMA_HOME=${T65MAX_COLIMA_HOME:-$EXTERNAL_VOLUME/t65max/colima-linux-home}
SSH_CONFIG="$COLIMA_HOME/ssh_config"
VM_HOST="colima-$PROFILE"
VM_HOME=$(ssh -F "$SSH_CONFIG" "$VM_HOST" 'printf %s "$HOME"')

ssh -t -F "$SSH_CONFIG" "$VM_HOST" "VM_ROOT='$VM_HOME/t65max' bash -s" <<'REMOTE'
set -u

log_dir="$VM_ROOT/project/lineage-build/logs/auto-build-single"
while :; do
    log=$(ls -1t "$log_dir"/round-*.log 2>/dev/null | head -1)
    build_pid=$(pgrep -o -f '[a]uto-build-inner.sh' || true)

    printf '\033[2J\033[H'
    date '+LineageOS build monitor — %H:%M:%S'
    if [ -n "$build_pid" ]; then
        elapsed=$(ps -p "$build_pid" -o etime= | tr -d ' ')
        echo "Status: actief — verstreken tijd $elapsed"
    else
        echo "Status: gestopt"
    fi

    if [ -n "${log:-}" ]; then
        progress=$(tail -n 4000 "$log" | tr '\r' '\n' | grep -E '\[[[:space:]]*[0-9]+%[[:space:]]+[0-9]+/[0-9]+\]' | tail -1 || true)
        if tail -n 30 "$log" | grep -q 'Running globs'; then
            echo "Fase: Soong analyseert bestandsglobs (geen percentage beschikbaar)"
        elif [ -n "$progress" ]; then
            echo "Voortgang: $progress"
        else
            phase=$(tail -n 30 "$log" | grep -v '^$' | tail -1)
            echo "Laatste stap: ${phase:-wachten op loguitvoer}"
        fi
    else
        echo "Log: nog niet aangemaakt"
    fi

    free -h | awk 'NR == 2 {print "RAM:  " $3 " / " $2 ", beschikbaar " $7} NR == 3 {print "Swap: " $3 " / " $2}'
    df -h "$VM_ROOT" | awk 'NR == 2 {print "Opslag: " $4 " vrij (" $5 " gebruikt)"}'

    if [ -z "$build_pid" ]; then
        echo
        [ -n "${log:-}" ] && tail -n 20 "$log"
        exit 0
    fi
    echo
    echo "Vernieuwt elke 60 seconden; Ctrl-C sluit alleen deze monitor."
    sleep 60
done
REMOTE
