#!/bin/bash
set -euo pipefail

SOURCE_DIR=/src
PROJECT_DIR=/project
SYNC_JOBS=${SYNC_JOBS:-1}

cd "$SOURCE_DIR"
git config --global user.name "T65 Max Builder"
git config --global user.email "t65max-builder@localhost"
git config --global color.ui false

if [[ ! -d .repo ]]; then
    repo init \
        -u https://github.com/LineageOS/android.git \
        -b lineage-23.2 \
        --git-lfs \
        --depth=1 \
        --no-clone-bundle
fi

mkdir -p .repo/local_manifests
cp "$PROJECT_DIR/lineage/build/t65max.xml" .repo/local_manifests/t65max.xml
repo sync -c --no-tags --no-clone-bundle --force-sync --fail-fast -j"$SYNC_JOBS"
