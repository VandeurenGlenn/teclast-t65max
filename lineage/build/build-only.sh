#!/bin/bash
set -eo pipefail

SOURCE_DIR=/src
PROJECT_DIR=/project
BUILD_JOBS=${BUILD_JOBS:-8}

cd "$SOURCE_DIR"
git config --global user.name "T65 Max Builder"
git config --global user.email "t65max-builder@localhost"

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
lunch lineage_t65max-bp4a-userdebug
m -j"$BUILD_JOBS" vendorbootimage
