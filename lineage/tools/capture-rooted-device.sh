#!/bin/sh
set -eu

# Capture privacy-conscious LineageOS/TWRP bring-up data from a rooted tablet.
# Raw logs can still contain incidental identifiers and must remain private.

ADB=${ADB:-adb}
OUT=${1:-work/device-captures/a8d4-rooted}
REMOTE_SCRIPT=/data/local/tmp/t65max-collect-rooted-device.sh
REMOTE_OUT=/data/local/tmp/t65max-a8d4-rooted-$$
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

mkdir -p "$OUT"

"$ADB" wait-for-device
"$ADB" push "$SCRIPT_DIR/collect-rooted-device-remote.sh" "$REMOTE_SCRIPT"
"$ADB" shell "su -c 'T65MAX_CAPTURE_DIR=$REMOTE_OUT sh $REMOTE_SCRIPT'"
"$ADB" pull "$REMOTE_OUT/." "$OUT/"
"$ADB" shell "su -c 'rm -rf $REMOTE_OUT $REMOTE_SCRIPT'"

printf 'Captured rooted bring-up data in %s\n' "$OUT"
