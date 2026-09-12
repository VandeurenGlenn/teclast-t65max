#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
PROFILE=${COLIMA_PROFILE:-lineage-fast}
SWAP_GIB=${T65MAX_SWAP_GIB:-8}
GO_MEMORY_LIMIT=${T65MAX_GO_MEMORY_LIMIT:-20GiB}
GO_GC=${T65MAX_GO_GC:-100}
SWAP_PATH=/var/lib/docker/.t65max-build.swap

if [ "$(uname -s)" = Darwin ] && \
   [ "$(sysctl -n kern.maxfilesperproc)" -lt 524288 ]; then
    echo "macOS file limit is too low for the VirtioFS Android source scan." >&2
    echo "Run ./lineage/build/configure-fast-colima-macos.sh first." >&2
    exit 8
fi

cleanup() {
    colima ssh --profile "$PROFILE" -- sudo sh -c \
        "swapoff '$SWAP_PATH' 2>/dev/null || true; rm -f '$SWAP_PATH'; fstrim /var/lib/docker >/dev/null 2>&1 || true" \
        >/dev/null 2>&1 || true
}
trap cleanup EXIT HUP INT TERM

if ! colima status --profile "$PROFILE" >/dev/null 2>&1; then
    colima start --profile "$PROFILE"
fi

SOURCE_REAL=$(CDPATH= cd -P -- "$PROJECT_DIR/lineage-build/source" && pwd)
case "$SOURCE_REAL" in
    /Volumes/*)
        RUNTIME_PROJECT=$(dirname "$SOURCE_REAL")/runtime-project
        mkdir -p "$RUNTIME_PROJECT/lineage" "$RUNTIME_PROJECT/lineage-build/logs"
        rsync -a --delete "$PROJECT_DIR/lineage/" "$RUNTIME_PROJECT/lineage/"
        for audit_file in auto-copy-rule-audit.tsv auto-install-conflict-audit.tsv; do
            if [ -f "$PROJECT_DIR/lineage-build/$audit_file" ]; then
                cp "$PROJECT_DIR/lineage-build/$audit_file" \
                    "$RUNTIME_PROJECT/lineage-build/$audit_file"
            fi
        done
        ln -sfn "$RUNTIME_PROJECT/lineage-build/logs" \
            "$PROJECT_DIR/lineage-build/live-logs"
        export T65MAX_RUNTIME_PROJECT="$RUNTIME_PROJECT"
        ;;
esac

docker context use "colima-$PROFILE" >/dev/null

cleanup
colima ssh --profile "$PROFILE" -- sudo sh -c \
    "fallocate -l '${SWAP_GIB}G' '$SWAP_PATH'; chmod 600 '$SWAP_PATH'; mkswap '$SWAP_PATH' >/dev/null; swapon '$SWAP_PATH'"

set +e
python3 "$PROJECT_DIR/lineage/build/auto-build.py" \
    --go-memory-limit "$GO_MEMORY_LIMIT" --go-gc "$GO_GC" "$@"
build_status=$?
set -e

if [ -n "${T65MAX_RUNTIME_PROJECT:-}" ]; then
    rsync -a "$T65MAX_RUNTIME_PROJECT/lineage-build/logs/" \
        "$PROJECT_DIR/lineage-build/logs/"
    for audit_file in auto-copy-rule-audit.tsv auto-install-conflict-audit.tsv; do
        if [ -f "$T65MAX_RUNTIME_PROJECT/lineage-build/$audit_file" ]; then
            cp "$T65MAX_RUNTIME_PROJECT/lineage-build/$audit_file" \
                "$PROJECT_DIR/lineage-build/$audit_file"
        fi
    done
fi

exit "$build_status"
