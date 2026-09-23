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
# Keep ccache on the VM's external-data-backed ext4 disk. The large Android
# out tree stays on the faster internal sparse disk, while reusable compiler
# objects no longer consume its scarce host allocation.
CCACHE_DIR=${CCACHE_DIR:-$SOURCE_DIR/../ccache}
CCACHE_EXEC=${CCACHE_EXEC:-$(command -v ccache)}
ROSETTA_RETRY_JOBS=${ROSETTA_RETRY_JOBS:-6}
OUT_DIR=${OUT_DIR:-out}
HOST_TOOL_SHIMS="$PROJECT_DIR/lineage/build/host-tools"
PATH="$HOST_TOOL_SHIMS:$PATH"
export GOMEMLIMIT GOGC GOMAXPROCS CCACHE_DIR CCACHE_EXEC USE_CCACHE=1 OUT_DIR PATH
BLOB_LIST="$PROJECT_DIR/lineage/device/teclast/t65max/proprietary-files.txt"
AUDIT_LOG="$PROJECT_DIR/lineage-build/auto-copy-rule-audit.tsv"
INSTALL_AUDIT_LOG="$PROJECT_DIR/lineage-build/auto-install-conflict-audit.tsv"
LOG_DIR="$PROJECT_DIR/lineage-build/logs/auto-build-single"
EXTRACT_STAMP="$SOURCE_DIR/out/.t65max-extract-inputs.sha256"

reset_rosetta_translation_cache() {
    # These files contain only Rosetta's reproducible x86_64 translations.
    # Android out/, Ninja state and ccache are deliberately untouched.
    sudo systemctl stop rosettad || true
    if [[ -d /var/cache/rosettad ]]; then
        sudo find /var/cache/rosettad -maxdepth 1 -type f \
            -name '*.aotcache' -delete
    fi
    if [[ -d "$HOME/.cache/rosetta" ]]; then
        find "$HOME/.cache/rosetta" -maxdepth 1 -type f -name '*.flu' -delete
    fi
    sudo systemctl reset-failed rosettad || true
    # Keep the optional AOT daemon disabled.  Its cached translations are not
    # required by the kernel Rosetta handler, and restarting it has caused
    # reproducible Translator.cpp/signapk crashes in this VM.
    echo "Rosetta translation cache cleared; AOT cache remains disabled"
}

disable_rosetta_aot_cache() {
    # Rosetta's optional AOT daemon occasionally aborts while translating the
    # x86_64 Android JDK (Translator.cpp assertions).  The kernel Rosetta
    # handler keeps working without this cache; only translations are no
    # longer persisted.  Keep Ninja/Soong outputs and ccache untouched.
    sudo systemctl stop rosettad || true
    echo "Rosetta AOT cache disabled; using stable on-demand x86 translation"
}

is_silent_transient_clang_failure() {
    local log_path=$1
    # Rosetta can occasionally return a failing status from an x86_64 clang
    # process without writing a diagnostic.  Treat only that narrow shape as
    # transient: a FAILED edge, an Android prebuilt clang command after it,
    # and no actual compiler/runtime diagnostic.  Retries are bounded below.
    awk '
        /^FAILED: / { after_failed = 1 }
        after_failed && /prebuilts\/clang\/host\/linux-x86\/.*\/clang(\+\+)? / {
            saw_clang = 1
        }
        after_failed && /(rosetta error:|Bus error|Killed|fatal error:|error: |Cannot allocate|No space left|Input\/output error|Segmentation fault|LLVM ERROR)/ {
            saw_diagnostic = 1
        }
        END { exit !(after_failed && saw_clang && !saw_diagnostic) }
    ' "$log_path"
}

soong_atomic_outputs_share_filesystem() {
    local sandbox_root="$SOURCE_DIR/out/soong/.temp"
    local generated_external="$SOURCE_DIR/out/soong/.intermediates/external"
    [[ ! -e "$sandbox_root" || ! -e "$generated_external" ]] \
        || [[ "$(stat -c %d "$sandbox_root")" == "$(stat -c %d "$generated_external")" ]]
}

require_soong_atomic_output_layout() {
    if ! soong_atomic_outputs_share_filesystem; then
        echo "Soong sandbox and generated external outputs are on different filesystems." >&2
        echo "Keep out/soong/.temp and out/soong/.intermediates/external on the same ext4 disk." >&2
        exit 4
    fi
}

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
require_soong_atomic_output_layout
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
python3 "$PROJECT_DIR/lineage/build/apply-kernel-header-python-compat.py" \
    --source "$SOURCE_DIR"
python3 "$PROJECT_DIR/lineage/build/apply-codec2-plugin-header-compat.py" \
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

NINJA_GRAPH="$SOURCE_DIR/out/combined-lineage_t65max.ninja"
NINJA_BIN="$SOURCE_DIR/prebuilts/build-tools/linux-x86/bin/ninja"
resume_ninja=false
current_build_jobs=$BUILD_JOBS

# A Rosetta ENOMEM and a repaired missing host tool do not invalidate the
# source graph. Resume the generated Ninja graph at lower concurrency when no
# build-definition file has changed since it was written. This avoids paying
# the multi-hour Soong/Kati analysis cost again after either failure.
latest_log=$(ls -1t "$LOG_DIR"/round-*.log 2>/dev/null | head -1 || true)
recoverable_previous_failure=false
soname_binary_recovery=false
lower_resume_jobs=false
disable_rosetta_aot_for_resume=false
if [[ -n "$latest_log" ]]; then
    if grep -Fq 'signapk.jar' "$latest_log" \
        && grep -Fq 'Bus error' "$latest_log"; then
        # The generated graph and signing inputs are valid.  Rosetta's AOT
        # daemon can crash on the x86_64 JDK while ordinary x86 tools remain
        # healthy; on-demand translation avoids that host-only failure.
        recoverable_previous_failure=true
        disable_rosetta_aot_for_resume=true
    elif grep -Fq 'rosetta error: Failed to map AOT header: 12' "$latest_log"; then
        recoverable_previous_failure=true
        lower_resume_jobs=true
    elif is_silent_transient_clang_failure "$latest_log"; then
        recoverable_previous_failure=true
        lower_resume_jobs=true
        disable_rosetta_aot_for_resume=true
    elif grep -Fq 'error: action cancelled when ninja exited' "$latest_log"; then
        # A deliberate SIGINT used for host-storage maintenance leaves all
        # completed outputs and the generated graph valid.
        recoverable_previous_failure=true
    elif grep -Fq 'header-abi-dumper' "$latest_log" \
        && grep -Fq 'Duplicate root dir:' "$latest_log"; then
        # Direct Ninja needs OUT_DIR exported for the literal
        # "--root-dir $OUT_DIR:out" command embedded in the graph. Missing
        # it changes that argument to ":out"; no source or output is bad.
        recoverable_previous_failure=true
    elif grep -Fq 'invalid cross-device link' "$latest_log" \
        && soong_atomic_outputs_share_filesystem; then
        # sbox completed the generator but could not atomically rename its
        # output across the manually split out filesystems. Once both paths
        # are colocated, the generated graph and all other outputs are valid.
        recoverable_previous_failure=true
    elif grep -Fq 'Cannot override existing value 31.0 with BOARD_SEPOLICY_VERS' \
        "$latest_log" \
        && ! grep -Fq '<sepolicy>' \
            "$SOURCE_DIR/device/teclast/t65max/configs/vintf/manifest.xml"; then
        # The stock merged manifest carried its resolved policy version, but
        # Lineage's assemble_vintf injects BOARD_SEPOLICY_VERS into this input.
        # Removing the duplicate value changes only this declared Ninja input.
        recoverable_previous_failure=true
    elif grep -Fq 'xxd: command not found' "$latest_log" \
        && command -v xxd >/dev/null; then
        recoverable_previous_failure=true
    elif grep -Fq 'device/teclast/t65max-kernel-a8d4/kernel-headers: No such file or directory' \
        "$latest_log" \
        && [[ -f "$SOURCE_DIR/device/teclast/t65max-kernel-a8d4/kernel-headers/Makefile" ]]; then
        recoverable_previous_failure=true
    elif grep -Fq 'DT_SONAME "android.hardware.audio.common-util.so" must be equal to the file name "android.hardware.audio.common-util_vendor.so"' \
        "$latest_log" \
        && readelf -d "$SOURCE_DIR/vendor/teclast/t65max/proprietary/vendor/lib64/android.hardware.audio.common-util_vendor.so" \
            | grep -Fq 'Library soname: [android.hardware.audio.common-util_vendor.so]' \
        && [[ "$SOURCE_DIR/out/soong/.intermediates/vendor/teclast/t65max/android.hardware.audio.common-util_vendor/android_vendor_arm64_armv8-2a-dotprod_cortex-a76_shared/android.hardware.audio.common-util_vendor.so.check_elf_file" \
            -nt "$SOURCE_DIR/vendor/teclast/t65max/proprietary/vendor/lib64/android.hardware.audio.common-util_vendor.so" ]]; then
        recoverable_previous_failure=true
        soname_binary_recovery=true
    elif grep -Fq 'DT_SONAME "libawinic.audio.effect.skt3.so" must be equal to the file name "awinic.audio.effect.so"' \
        "$latest_log" \
        && readelf -d "$SOURCE_DIR/vendor/teclast/t65max/proprietary/vendor/lib64/hw/awinic.audio.effect.so" \
            | grep -Fq 'Library soname: [awinic.audio.effect.so]' \
        && [[ "$SOURCE_DIR/out/soong/.intermediates/vendor/teclast/t65max/awinic.audio.effect/android_vendor_arm64_armv8-2a-dotprod_cortex-a76_shared/awinic.audio.effect.so.check_elf_file" \
            -nt "$SOURCE_DIR/vendor/teclast/t65max/proprietary/vendor/lib64/hw/awinic.audio.effect.so" ]]; then
        recoverable_previous_failure=true
        soname_binary_recovery=true
    elif ! grep -Eq 'FAILED:|ninja: build stopped|failed to build some targets|build stopped on' \
        "$latest_log" \
        && tail -n 1 "$latest_log" | grep -Eq '^\[[[:space:]]*[0-9]+% [0-9]+/[0-9]+\] '; then
        # Ninja was terminated outside the build graph (for example by the VM
        # OOM killer or a lost SSH session). Its completed outputs and graph
        # remain reusable when the definition timestamp guard below passes.
        recoverable_previous_failure=true
    fi
fi
if $recoverable_previous_failure \
    && [[ -f "$NINJA_GRAPH" && -x "$NINJA_BIN" ]]; then
    if $soname_binary_recovery; then
        # extract-utils rewrites the generated vendor make/Blueprint files
        # after a blob-only FIX_SONAME repair, even though their module graph
        # is unchanged. The exact ELF target above has already passed against
        # this Ninja graph, so ignore only that generated vendor directory.
        newer_definition=$(find "$SOURCE_DIR" \
            -path "$SOURCE_DIR/out" -prune -o \
            -path "$SOURCE_DIR/.repo" -prune -o \
            -path "$SOURCE_DIR/vendor/teclast/t65max" -prune -o \
            -type f \( -name Android.bp -o -name Android.mk -o -name '*.mk' \) \
            -newer "$NINJA_GRAPH" -print -quit)
    else
        newer_definition=$(find "$SOURCE_DIR" \
            -path "$SOURCE_DIR/out" -prune -o \
            -path "$SOURCE_DIR/.repo" -prune -o \
            -type f \( -name Android.bp -o -name Android.mk -o -name '*.mk' \) \
            -newer "$NINJA_GRAPH" -print -quit)
    fi
    if [[ -z "$newer_definition" ]]; then
        $disable_rosetta_aot_for_resume && disable_rosetta_aot_cache
        resume_ninja=true
        $lower_resume_jobs && (( current_build_jobs > ROSETTA_RETRY_JOBS )) \
            && current_build_jobs=$ROSETTA_RETRY_JOBS
        echo "guarded fast resume: reusing Ninja graph with -j$current_build_jobs"
    else
        echo "Ninja fast resume disabled; newer build definition: $newer_definition"
    fi
fi

for ((round_number = 1; round_number <= MAX_ROUNDS; round_number++)); do
    log_path="$LOG_DIR/round-$(printf '%02d' "$round_number").log"
    if $resume_ninja; then
        echo "round $round_number: resuming Ninja $BUILD_TARGET with -j$current_build_jobs"
    else
        echo "round $round_number: building $BUILD_TARGET with -j$current_build_jobs"
    fi
    set +e
    if $resume_ninja; then
        NINJA_STATUS='[%p %f/%t] ' "$NINJA_BIN" \
            -d keepdepfile -d keeprsp -f "$NINJA_GRAPH" \
            -j"$current_build_jobs" "$BUILD_TARGET" >"$log_path" 2>&1
    else
        m -j"$current_build_jobs" "$BUILD_TARGET" >"$log_path" 2>&1
    fi
    build_status=$?
    set -e

    if [[ $build_status -eq 0 ]]; then
        echo "build succeeded; log: $log_path"
        exit 0
    fi

    if grep -Fq 'signapk.jar' "$log_path" \
        && grep -Fq 'Bus error' "$log_path"; then
        if systemctl is-active --quiet rosettad; then
            disable_rosetta_aot_cache
        elif (( current_build_jobs > 4 )); then
            # A second failure without AOT caching points to translation
            # pressure rather than the known daemon assertion.
            current_build_jobs=4
        else
            echo "signapk still crashes with Rosetta AOT disabled at -j$current_build_jobs; stopping." >&2
            tail -n 30 "$log_path" >&2
            exit "$build_status"
        fi
        resume_ninja=true
        echo "signapk Rosetta crash detected; retrying the same Ninja graph with -j$current_build_jobs"
        continue
    fi

    if grep -Fq 'rosetta error: Failed to map AOT header: 12' "$log_path"; then
        if (( current_build_jobs > ROSETTA_RETRY_JOBS )); then
            current_build_jobs=$ROSETTA_RETRY_JOBS
        elif (( current_build_jobs > 4 )); then
            current_build_jobs=4
        else
            echo "Rosetta ENOMEM persisted at -j$current_build_jobs; stopping." >&2
            tail -n 30 "$log_path" >&2
            exit "$build_status"
        fi
        reset_rosetta_translation_cache
        resume_ninja=true
        echo "Rosetta ENOMEM detected; cache reset, retrying the same Ninja graph with -j$current_build_jobs"
        continue
    fi

    if is_silent_transient_clang_failure "$log_path"; then
        if (( current_build_jobs > ROSETTA_RETRY_JOBS )); then
            current_build_jobs=$ROSETTA_RETRY_JOBS
        elif (( current_build_jobs > 4 )); then
            current_build_jobs=4
        else
            echo "Silent Rosetta clang failure persisted at -j$current_build_jobs; stopping." >&2
            tail -n 30 "$log_path" >&2
            exit "$build_status"
        fi
        disable_rosetta_aot_cache
        resume_ninja=true
        echo "Silent Rosetta clang failure detected; retrying the same Ninja graph with -j$current_build_jobs"
        continue
    fi

    if grep -Fq 'xxd: command not found' "$log_path"; then
        echo "Required host tool xxd is missing; run provision-direct-linux-build-macos.sh." >&2
        exit "$build_status"
    fi

    if grep -Fq 'device/teclast/t65max-kernel-a8d4/kernel-headers: No such file or directory' \
        "$log_path"; then
        echo "Exact stock kernel UAPI headers are missing; regenerate the kernel-headers shim." >&2
        exit "$build_status"
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
    resume_ninja=false
done

echo "stopped after $MAX_ROUNDS rounds" >&2
exit 3
