#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
EXTERNAL_VOLUME=${T65MAX_BUILD_VOLUME:-/Volumes/LineageBuild}
PROFILE=${COLIMA_PROFILE:-lineage-linux}
export COLIMA_HOME=${T65MAX_COLIMA_HOME:-$EXTERNAL_VOLUME/t65max/colima-linux-home}
SOURCE_DIR="$EXTERNAL_VOLUME/t65max/source"
SSH_CONFIG="$COLIMA_HOME/ssh_config"
VM_HOST="colima-$PROFILE"
VM_DATA_ROOT=/var/lib/docker/t65max
MIGRATION_DIR="$EXTERNAL_VOLUME/t65max/colima-migration"
OUT_ARCHIVE="$MIGRATION_DIR/t65max-lineage-out.tar"
BUILDER_ARCHIVE="$MIGRATION_DIR/t65max-lineage-builder.tar"

if [ ! -d "$SOURCE_DIR/.repo" ]; then
    echo "Source migration is already complete or the source is unavailable." >&2
    exit 2
fi

if ! colima status --profile "$PROFILE" >/dev/null 2>&1; then
    "$PROJECT_DIR/lineage/build/configure-linux-colima-macos.sh"
fi

VM_HOME=$(ssh -F "$SSH_CONFIG" "$VM_HOST" 'printf %s "$HOME"')
VM_ROOT="$VM_HOME/t65max"

ssh -F "$SSH_CONFIG" "$VM_HOST" \
    "sudo mkdir -p '$VM_DATA_ROOT/source' '$VM_DATA_ROOT/project' && sudo chown -R \$(id -u):\$(id -g) '$VM_DATA_ROOT' && mkdir -p '$VM_ROOT' && (mountpoint -q '$VM_ROOT' || sudo mount --bind '$VM_DATA_ROOT' '$VM_ROOT')"

echo "Moving Android source into the VM-native ext4 disk. This is resumable."
rsync -aH --partial --progress --stats --remove-source-files \
    -e "ssh -F $SSH_CONFIG" \
    "$SOURCE_DIR/" "$VM_HOST:$VM_ROOT/source/"

find "$SOURCE_DIR" -depth -type d -empty -delete 2>/dev/null || true

if [ -f "$OUT_ARCHIVE" ] && ! ssh -F "$SSH_CONFIG" "$VM_HOST" test -f "$VM_ROOT/out/.t65max-out-restored"; then
    echo "Restoring the existing out cache directly onto ext4."
    ssh -F "$SSH_CONFIG" "$VM_HOST" "mkdir -p '$VM_ROOT/out' && tar -xf - -C '$VM_ROOT/out' && touch '$VM_ROOT/out/.t65max-out-restored'" \
        <"$OUT_ARCHIVE"
fi

if ! ssh -F "$SSH_CONFIG" "$VM_HOST" test -f "$VM_ROOT/source/build/envsetup.sh"; then
    echo "Migration verification failed; temporary migration files were preserved." >&2
    exit 7
fi

# These two archives are derived migration work products, not firmware or
# project backups. Remove them only after their VM-native replacements exist.
if ssh -F "$SSH_CONFIG" "$VM_HOST" test -f "$VM_ROOT/out/.t65max-out-restored"; then
    rm -f "$OUT_ARCHIVE"
fi
rm -f "$BUILDER_ARCHIVE"
rmdir "$MIGRATION_DIR" 2>/dev/null || true

echo "Migration complete. Source and out cache live at $VM_ROOT on native ext4."
