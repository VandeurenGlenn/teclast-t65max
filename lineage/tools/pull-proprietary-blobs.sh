#!/bin/sh
set -eu

ADB=${ADB:-adb}
MODE=${1:-estimate}
DEVICE_PATH=${DEVICE_PATH:-lineage/device/teclast/t65max}
DEST=${DEST:-lineage/vendor/teclast/t65max/proprietary}
SOURCE_LIST=${SOURCE_LIST:-$DEVICE_PATH/proprietary-files.txt}
LIST=/tmp/t65max-a8d4-blob-paths.txt
REMOTE_LIST=/data/local/tmp/t65max-a8d4-blob-paths.txt
REMOTE_SCRIPT=/data/local/tmp/t65max-blob-archive-remote.sh
REMOTE_ARCHIVE=/data/local/tmp/t65max-a8d4-blobs.tar

awk '
  /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
  {
    sub(/^-/, "")
    sub(/;.*/, "")
    sub(/:.*/, "")
    sub(/^\//, "")
    print
  }
' "$SOURCE_LIST" > "$LIST"

"$ADB" wait-for-device
"$ADB" push "$LIST" "$REMOTE_LIST"
"$ADB" push lineage/tools/blob-archive-remote.sh "$REMOTE_SCRIPT"

case "$MODE" in
    estimate)
        "$ADB" shell "su -c 'sh $REMOTE_SCRIPT estimate'"
        ;;
    pull)
        "$ADB" shell "su -c 'sh $REMOTE_SCRIPT archive'"
        mkdir -p "$DEST"
        "$ADB" pull "$REMOTE_ARCHIVE" /tmp/t65max-a8d4-blobs.tar
        tar -xf /tmp/t65max-a8d4-blobs.tar -C "$DEST"
        "$ADB" shell "su -c 'sh $REMOTE_SCRIPT cleanup'"
        rm -f /tmp/t65max-a8d4-blobs.tar "$LIST"
        ;;
    *)
        echo "Usage: $0 [estimate|pull]" >&2
        exit 2
        ;;
esac
