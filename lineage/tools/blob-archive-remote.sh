#!/system/bin/sh
set -eu

MODE=${1:-estimate}
LIST=/data/local/tmp/t65max-a8d4-blob-paths.txt
ARCHIVE=/data/local/tmp/t65max-a8d4-blobs.tar

case "$MODE" in
    estimate)
        total=0
        present=0
        missing=0
        while IFS= read -r file; do
            path="/$file"
            if [ -e "$path" ] || [ -L "$path" ]; then
                size=$(stat -c %s "$path" 2>/dev/null || echo 0)
                total=$((total + size))
                present=$((present + 1))
            else
                missing=$((missing + 1))
            fi
        done < "$LIST"
        printf 'present=%s missing=%s bytes=%s\n' "$present" "$missing" "$total"
        ;;
    archive)
        rm -f "$ARCHIVE"
        cd /
        # Toybox tar 0.8.11 on this stock build segfaults while reading some
        # SELinux labels. Blob extraction needs paths/content/symlinks; policy
        # labels are supplied by the build, not restored from this archive.
        tar -cf "$ARCHIVE" -T "$LIST"
        chmod 0644 "$ARCHIVE"
        stat -c 'bytes=%s' "$ARCHIVE"
        ;;
    cleanup)
        rm -f "$LIST" "$ARCHIVE" /data/local/tmp/t65max-blob-archive-remote.sh
        ;;
    *)
        echo "Unknown mode: $MODE" >&2
        exit 2
        ;;
esac
