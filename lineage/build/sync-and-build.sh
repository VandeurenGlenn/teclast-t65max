#!/bin/bash
set -euo pipefail

SOURCE_DIR=/src
PROJECT_DIR=/project
SYNC_JOBS=${SYNC_JOBS:-4}
BUILD_JOBS=${BUILD_JOBS:-8}

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
repo sync -c --no-tags --no-clone-bundle --force-sync -j"$SYNC_JOBS"

mkdir -p device/teclast vendor/teclast
rsync -a --delete "$PROJECT_DIR/lineage/device/teclast/t65max/" \
    device/teclast/t65max/
rsync -a --delete "$PROJECT_DIR/lineage/device/teclast/t65max-kernel-a8d4/" \
    device/teclast/t65max-kernel-a8d4/

cd device/teclast/t65max
./extract-files.py "$PROJECT_DIR/lineage/vendor/teclast/t65max/proprietary"

cd "$SOURCE_DIR"
ccache -M 20G
source build/envsetup.sh
lunch lineage_t65max-userdebug
m -j"$BUILD_JOBS" vendorbootimage
