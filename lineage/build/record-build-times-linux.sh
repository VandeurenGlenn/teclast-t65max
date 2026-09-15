#!/bin/bash
set -u

: "${VM_ROOT:?VM_ROOT is required}"
log_dir="$VM_ROOT/project/lineage-build/logs/auto-build-single"
state_file="$log_dir/.follow-timing-state.tsv"
history_file="$log_dir/build-times.tsv"
lock_dir="$log_dir/.timing-recorder.lock"
mkdir -p "$log_dir"
mkdir "$lock_dir" 2>/dev/null || exit 0
trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT

build_pid=$(pgrep -o -f '[a]uto-build-inner.sh' || true)
[ -n "$build_pid" ] || exit 0
now=$(date +%s)
build_elapsed=$(ps -p "$build_pid" -o etimes= | tr -d ' ')
build_start=$((now - build_elapsed))
soong_start=0
soong_total=0
ninja_start=0
ninja_total=0

# Continue a timing session previously seeded by follow.
if [ -s "$state_file" ]; then
    IFS=$'\t' read -r old_build_start old_soong_start old_soong_total \
        old_ninja_start old_ninja_total <"$state_file" || true
    delta=$((old_build_start - build_start))
    [ "$delta" -lt 0 ] && delta=$((-delta))
    if [ "$delta" -le 5 ]; then
        soong_start=${old_soong_start:-0}
        soong_total=${old_soong_total:-0}
        ninja_start=${old_ninja_start:-0}
        ninja_total=${old_ninja_total:-0}
    fi
fi

save_state() {
    printf '%s\t%s\t%s\t%s\t%s\n' \
        "$build_start" "$soong_start" "$soong_total" "$ninja_start" "$ninja_total" \
        >"$state_file.tmp.$$"
    mv "$state_file.tmp.$$" "$state_file"
}

while kill -0 "$build_pid" 2>/dev/null; do
    now=$(date +%s)
    log=$(ls -1t "$log_dir"/round-*.log 2>/dev/null | head -1)
    soong_pid=$(pgrep -o -x soong_build || true)
    ninja_pid=$(pgrep -o -f '[n]inja .*out/combined-lineage_t65max\.ninja' || true)

    if [ -n "$soong_pid" ]; then
        soong_elapsed=$(ps -p "$soong_pid" -o etimes= | tr -d ' ')
        soong_start=$((now - soong_elapsed))
    elif [ "$soong_start" -gt 0 ]; then
        soong_total=$((soong_total + now - soong_start))
        soong_start=0
    fi

    main_ninja=false
    if [ -n "${log:-}" ] && [ -n "$ninja_pid" ]; then
        progress=$(tail -n 4000 "$log" | tr '\r' '\n' \
            | grep -E '\[[[:space:]]*[0-9]+%[[:space:]]+[0-9]+/[0-9]+\]' | tail -1 || true)
        total=$(printf '%s\n' "$progress" | sed -nE \
            's/.*\[[[:space:]]*[0-9]+%[[:space:]]+[0-9]+\/([0-9]+)\].*/\1/p')
        [ -n "$total" ] && [ "$total" -ge 1000 ] && main_ninja=true
    fi
    if $main_ninja; then
        ninja_elapsed=$(ps -p "$ninja_pid" -o etimes= | tr -d ' ')
        [ "$ninja_start" -gt 0 ] || ninja_start=$((now - ninja_elapsed))
    elif [ "$ninja_start" -gt 0 ]; then
        ninja_total=$((ninja_total + now - ninja_start))
        ninja_start=0
    fi

    save_state
    sleep 5
done

finish_epoch=$(date +%s)
log=$(ls -1t "$log_dir"/round-*.log 2>/dev/null | head -1)
[ "$soong_start" -gt 0 ] && soong_total=$((soong_total + finish_epoch - soong_start))
[ "$ninja_start" -gt 0 ] && ninja_total=$((ninja_total + finish_epoch - ninja_start))
result=failed
if [ -n "${log:-}" ] && grep -q 'build completed successfully' "$log" 2>/dev/null; then
    result=succeeded
fi
if [ ! -f "$history_file" ]; then
    printf 'finished_at\tstart_epoch\tresult\ttotal_seconds\tsoong_seconds\tninja_seconds\tlog\n' >"$history_file"
fi
if ! awk -F '\t' -v start="$build_start" \
    'NR > 1 && $2 == start { found=1 } END { exit !found }' "$history_file"; then
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$(date -d "@$finish_epoch" --iso-8601=seconds)" "$build_start" "$result" \
        "$((finish_epoch - build_start))" "$soong_total" "$ninja_total" "${log##*/}" \
        >>"$history_file"
fi
rm -f "$state_file"
