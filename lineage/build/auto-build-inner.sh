#!/bin/bash
set -eo pipefail

SOURCE_DIR=${SOURCE_DIR:-/src}
PROJECT_DIR=${PROJECT_DIR:-/project}
BUILD_JOBS=${BUILD_JOBS:-3}
MAX_ROUNDS=${MAX_ROUNDS:-50}
GOMEMLIMIT=${GOMEMLIMIT:-16GiB}
GOGC=${GOGC:-50}
GOMAXPROCS=${GOMAXPROCS:-6}
BUILD_TARGET=${BUILD_TARGET:-vendorbootimage}
CCACHE_MAX_SIZE=${CCACHE_MAX_SIZE:-6G}
CCACHE_DIR=${CCACHE_DIR:-$SOURCE_DIR/out/.ccache}
CCACHE_EXEC=${CCACHE_EXEC:-$(command -v ccache)}
HOST_TOOL_SHIMS="$PROJECT_DIR/lineage/build/host-tools"
PATH="$HOST_TOOL_SHIMS:$PATH"
export GOMEMLIMIT GOGC GOMAXPROCS CCACHE_DIR CCACHE_EXEC USE_CCACHE=1 PATH
BLOB_LIST="$PROJECT_DIR/lineage/device/teclast/t65max/proprietary-files.txt"
AUDIT_LOG="$PROJECT_DIR/lineage-build/auto-copy-rule-audit.tsv"
INSTALL_AUDIT_LOG="$PROJECT_DIR/lineage-build/auto-install-conflict-audit.tsv"
LOG_DIR="$PROJECT_DIR/lineage-build/logs/auto-build-single"
EXTRACT_STAMP="$SOURCE_DIR/out/.t65max-extract-inputs.sha256"

extract_inputs_fingerprint() {
    {
        sha256sum \
            "$PROJECT_DIR/lineage/device/teclast/t65max/extract-files.py" \
            "$PROJECT_DIR/lineage/device/teclast/t65max/setup-makefiles.py" \
            "$PROJECT_DIR/lineage/device/teclast/t65max/proprietary-files.txt" \
            "$PROJECT_DIR/lineage/device/teclast/t65max/proprietary-firmware.txt" \
            "$PROJECT_DIR/lineage/inventory/a8d4/proprietary-sha256.txt"
        find "$PROJECT_DIR/lineage/vendor/teclast/t65max/proprietary" \
            -type f -printf '%P\t%s\t%T@\n' | LC_ALL=C sort
    } | sha256sum | awk '{print $1}'
}

sync_and_extract() {
    mkdir -p "$SOURCE_DIR/device/teclast" "$SOURCE_DIR/vendor/teclast"
    rsync -a --delete "$PROJECT_DIR/lineage/device/teclast/t65max/" \
        "$SOURCE_DIR/device/teclast/t65max/"
    rsync -a --delete "$PROJECT_DIR/lineage/device/teclast/t65max-kernel-a8d4/" \
        "$SOURCE_DIR/device/teclast/t65max-kernel-a8d4/"

    local fingerprint
    fingerprint="$(extract_inputs_fingerprint)"
    if [[ -f "$EXTRACT_STAMP" ]] \
        && [[ "$(<"$EXTRACT_STAMP")" == "$fingerprint" ]] \
        && [[ -f "$SOURCE_DIR/vendor/teclast/t65max/Android.bp" ]]; then
        echo "proprietary inputs unchanged; reusing generated vendor tree"
        return
    fi

    cd "$SOURCE_DIR/device/teclast/t65max"
    ./extract-files.py "$PROJECT_DIR/lineage/vendor/teclast/t65max/proprietary"
    printf '%s\n' "$fingerprint" >"$EXTRACT_STAMP"
}

mkdir -p "$LOG_DIR"
python3 "$PROJECT_DIR/lineage/build/apply-kati-install-conflicts.py" \
    --normalize-renames \
    --blob-list "$BLOB_LIST" \
    --audit-log "$INSTALL_AUDIT_LOG" \
    --round preflight-renamed-modules
sync_and_extract
python3 "$PROJECT_DIR/lineage/build/apply-casefold-source-fixes.py" \
    --source "$SOURCE_DIR"
python3 "$PROJECT_DIR/lineage/build/apply-clang-version-compat.py" \
    --source "$SOURCE_DIR"
python3 "$PROJECT_DIR/lineage/build/apply-soong-memory-limits.py" \
    --source "$SOURCE_DIR"

cd "$SOURCE_DIR"
git config --global user.name "T65 Max Builder"
git config --global user.email "t65max-builder@localhost"
mkdir -p "$CCACHE_DIR"
ccache -M "$CCACHE_MAX_SIZE"
source build/envsetup.sh
lunch lineage_t65max-bp4a-userdebug

for ((round_number = 1; round_number <= MAX_ROUNDS; round_number++)); do
    log_path="$LOG_DIR/round-$(printf '%02d' "$round_number").log"
    echo "round $round_number: building $BUILD_TARGET"
    set +e
    m -j"$BUILD_JOBS" "$BUILD_TARGET" >"$log_path" 2>&1
    build_status=$?
    set -e

    if [[ $build_status -eq 0 ]]; then
        echo "build succeeded; log: $log_path"
        exit 0
    fi

    set +e
    python3 "$PROJECT_DIR/lineage/build/restore-missing-source-paths.py" \
        --log "$log_path" \
        --source "$SOURCE_DIR"
    fix_status=$?
    set -e

    if [[ $fix_status -ne 0 ]]; then
        set +e
        python3 "$PROJECT_DIR/lineage/build/retry-transient-aidl-checks.py" \
            --log "$log_path" \
            --source "$SOURCE_DIR"
        fix_status=$?
        set -e
    fi

    if [[ $fix_status -ne 0 ]]; then
        set +e
        python3 "$PROJECT_DIR/lineage/build/apply-partition-conflicts.py" \
            --log "$log_path" \
            --blob-list "$BLOB_LIST" \
            --audit-log "$AUDIT_LOG" \
            --round "round-$(printf '%02d' "$round_number")"
        fix_status=$?
        set -e
    fi

    if [[ $fix_status -ne 0 ]]; then
        set +e
        python3 "$PROJECT_DIR/lineage/build/apply-kati-install-conflicts.py" \
            --log "$log_path" \
            --blob-list "$BLOB_LIST" \
            --audit-log "$INSTALL_AUDIT_LOG" \
            --installs-mk "$SOURCE_DIR/out/soong/installs-lineage_t65max.mk" \
            --round "round-$(printf '%02d' "$round_number")"
        fix_status=$?
        set -e
        if [[ $fix_status -ne 0 ]]; then
            echo "build stopped on a non-automated or ambiguous error; log: $log_path" >&2
            tail -n 30 "$log_path" >&2
            exit "$build_status"
        fi
    fi

    sync_and_extract
    cd "$SOURCE_DIR"
done

echo "stopped after $MAX_ROUNDS rounds" >&2
exit 3
