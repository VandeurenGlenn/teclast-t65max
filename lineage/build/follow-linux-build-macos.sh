#!/bin/sh
set -eu

EXTERNAL_VOLUME=${T65MAX_BUILD_VOLUME:-/Volumes/LineageBuild}
PROFILE=${COLIMA_PROFILE:-lineage-linux}
export COLIMA_HOME=${T65MAX_COLIMA_HOME:-$EXTERNAL_VOLUME/t65max/colima-linux-home}
SSH_CONFIG="$COLIMA_HOME/ssh_config"
VM_HOST="colima-$PROFILE"
VM_HOME=$(ssh -F "$SSH_CONFIG" "$VM_HOST" 'printf %s "$HOME"')

exec ssh -t -F "$SSH_CONFIG" "$VM_HOST" \
    "tail -n 40 -F '$VM_HOME/t65max/project/lineage-build/logs/auto-build-single/round-01.log'"
