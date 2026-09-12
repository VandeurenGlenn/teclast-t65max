# T65 Max LineageOS project memory

This file records durable engineering decisions for future bring-up work. It
does not claim that the current tree boots or is safe to flash.

## Workflow efficiency

- Minimize tokens and repetitive status narration. Report only meaningful
  progress, failures, decisions, required user actions and completed results.
- Before repeating any expensive build, extraction, scan or validation step,
  measure what invalidated its cache and automate the narrowest safe
  incremental path. Reuse verified outputs and fingerprints by default.
- When a task becomes repetitive, improve the script/tool immediately rather
  than paying the same startup or analysis cost again. Keep a full correctness
  path for build-graph changes and a guarded fast path for content-only edits.

## Proprietary vendor policy

- Minimize Teclast/stock proprietary content. Prefer working LineageOS/AOSP
  source implementations and suitable open-source MediaTek components.
- Retain a stock blob only when it is required by the verified A8D4 hardware
  contract or by another retained proprietary component and no validated
  source-built replacement is available.
- Treat `MAKE_COPY_RULE_ONLY` as an installation mechanism, not as blob
  removal. It copies a blob without generating a normal prebuilt module and
  can avoid duplicate-module or build-system processing conflicts.
- Entries such as legacy HIDL/Binder/Codec2 compatibility libraries are
  candidates for removal, not automatic removals. Establish reverse
  dependencies first, remove one coherent group at a time, rebuild, and test
  boot plus the affected hardware paths.
- Replace stock resource-overlay APKs with source-built device overlays when
  their required resources have been identified and validated. Remove the
  stock APK only after the replacement is proven equivalent.
- Do not remove blobs merely to reduce the count, and do not use
  `MAKE_COPY_RULE_ONLY` to hide an unresolved dependency or duplicate-module
  problem. Record why every exception remains.

## Validation rule

Blob reduction must remain evidence-driven. At minimum, check generated build
rules and ELF dependencies before removal. Runtime validation should cover the
affected subsystem and must preserve recovery and rollback paths. High-impact
changes involving boot, encryption, radio, camera, audio, graphics, sensors or
suspend require on-device validation before being considered complete.

## Android 15 vendor blobs on LineageOS 23.2

- A8D4 executables and libraries that require frozen AIDL libraries named
  `*-ndk_platform.so` are patched during extraction to use Android 16's
  corresponding `*-ndk.so` sonames. The observed set currently covers light,
  memtrack, vibrator, GNSS, power, KeyMint, SharedSecret and SecureClock.
- Keep the stock `libkeymint.so` and
  `lib_android_keymaster_keymint_utils.so` as separately named `_vendor`
  modules and files, and rewrite their proprietary callers during extraction.
  Renaming only the modules still collides at the installed filename; using
  distinct sonames avoids that Kati collision and prevents the Android 15
  blobs from loading Android 16's incompatible source implementation.
- The Linux Clang sparse checkout needs `clang-stable` in addition to the
  release compiler. For this local BP4A tree the Trusty dirgroup is pointed at
  the available `clang-r563880c`; downloading the unused historical compiler
  worktrees increased Soong scan cost without helping the T65 Max target.
- On the 24 GB Apple Silicon build host, an earlier 16 GB Colima VM was
  OOM-killed during unconstrained Soong analysis. The guarded build now uses a
  16 GB VM plus temporary VM swap and bounded Go memory, leaving enough RAM for
  macOS. This is a build-host workaround, not a device-tree validation result.
- Soong analysis of this checkout reached 21.6 GB resident memory and exhausted
  a 22 GB VM plus 4 GB swap. The automated build now bounds the Go heap with
  `GOMEMLIMIT=16GiB` and `GOGC=50`. Because Soong deliberately launches its
  primary builder with an empty environment, the build preflight idempotently
  passes only those two Go controls into that sanitized subprocess. Prefer this
  guarded setting over repeatedly enlarging the VM or consuming scarce host
  storage with swap.
- On the 24 GB macOS host, use `build/run-auto-build-linux-macos.sh`. It runs
  Android directly as the ordinary user in the `lineage-linux` VM and creates
  an 8 GB temporary swap file on the VM data disk. The exit trap removes swap
  and trims the disk so APFS can reclaim host space. Docker is not in the build
  path.
- For a complete flashable LineageOS package, use
  `build/run-full-build-limited-macos.sh`. It builds `bacon` with three jobs,
  a 16 GiB Go heap limit, 8 GiB temporary VM swap, and a persistent bounded
  12 GiB ccache inside the VM-native `out` directory. It refuses to start with
  less than 60 GiB free on the external build volume.
- Do not use the `lineage-fast` VirtioFS profile. Two repeatable macOS 27.0
  panics occurred while its VZ VM accessed the external USB source tree: first
  `watchdogd` and then `launchd` exited with signal 10, with a VirtioFS thread
  blocked in kernel I/O during the second panic. The stable profile is
  `lineage-linux`: 6 vCPUs, 16 GiB RAM, Rosetta, no host directory mounts, and
  a native Linux ext4 data disk backed by a sparse image on the external SSD.
  Source and the restored `out` cache were migrated over SSH onto that ext4
  disk. They belong to the ordinary Lima user. Root is limited to one-time VM
  provisioning, the targeted ext4 bind mount and temporary swap management;
  Android build commands never run as root. The small workspace project tree
  is mirrored over SSH before each build and logs are copied back afterward.
- The former Docker workflow remains only as a legacy fallback under
  `lineage/build`; the supported full-build entry point does not invoke it.
- The `lineage-linux` VM itself is arm64, while this Android checkout supplies
  `linux-x86` host prebuilts. Rosetta executes those x86_64 tools successfully.
  The direct-build preflight shadows only `uname -m` as `x86_64`, causing the
  AOSP bootstrap to select the supplied host tools without falsifying other
  kernel information or changing the ARM64 device target.
- The former case-insensitive checkout lost some tracked case-colliding files.
  After explicit destructive-reset authorization, the VM checkout was restored
  locally to its manifest revisions without touching `out` or ccache. The 6.8
  GiB standalone sparse clang checkout is the only manifest exception: forcing
  Repo's empty object linkage would discard its required `clang-r563880c`
  selection and locally present compiler payloads. When Soong later reports an
  exact missing module source, the build loop still restores only that tracked
  path from its owning repository's `HEAD`.
- Use LineageOS's source-built `android.hardware.health@2.1-impl` instead of
  retaining the stock `android.hardware.health@2.0-impl-2.1.so`. Both install
  the same vendor hw-library path, and keeping the prebuilt creates a Kati
  duplicate-target failure.
- Always retain extract-utils' standard `lib_fixups`; these map stock vendor
  protobuf dependencies such as `libprotobuf-cpp-lite-3.9.1` to Lineage's
  `-vendorcompat` modules. Device-specific KeyMint renaming is implemented via
  destination filenames and blob fixups, not by replacing the standard map.
- Prefer `hardware/mediatek/wlan/wlan_assistant/wlan_assistant.rc` over the
  captured stock copy. Their contents are byte-identical except for the final
  newline, while installing both produces a Kati duplicate-target failure.
- The Kati conflict resolver scans the complete generated Soong install list,
  because Kati itself reports only the first duplicate. Copy-only stock HIDL
  interface libraries installed directly under `vendor/lib{,64}` are replaced
  by their matching source-built vendor variants as one coherent group. It
  does not generalize this rule to `hw/` implementations or unknown targets.
- Use the source-built 32-bit `libavservices_minijail.so`. The retained
  proprietary MediaTek Codec2 services already use the separately packaged
  `libavservices_minijail_vendor.so`; only the stock OMX service requests the
  unsuffixed library, for which the build provides a vendor source variant.
- Treat the direct-install Codec2 framework support libraries as one source
  replacement group for both bitnesses: `libcodec2_hidl@1.[0-2]`,
  `libcodec2_soft_common`, `libcodec2_vndk`,
  `libsfplugin_ccodec_utils`, and `libstagefright_bufferpool@2.0.1`. Soong
  supplies matching vendor variants; retaining copy-only stock files creates
  serial Kati target collisions. Runtime media validation remains required.
- Prefer Lineage's source-built vendor variants of `libdrm`, `libhwbinder`,
  and `libhidltransport` for both bitnesses. These generic transport libraries
  collide with copy-only stock files at identical install paths; device-specific
  DRM services and implementations remain proprietary. Runtime DRM and HIDL
  service validation remains required.
- Use Lineage's 32-bit vendor media-codec support libraries instead of the
  duplicate copy-only stock files: `libopus`, `libstagefright_amrnb_common`,
  `libstagefright_enc_common`, `libstagefright_flacdec`,
  `libstagefright_softomx`, `libstagefright_softomx_plugin`, and
  `libvorbisidec`. They are handled as one coherent source-replacement group;
  runtime audio/video encode and decode validation remains required.
- Use the source-built MediaTek Power HIDL interface libraries
  `vendor.mediatek.hardware.mtkpower@1.[0-2]` for both bitnesses. Keep the
  proprietary `hw/...mtkpower@1.2-impl.so` implementation and service; only
  the duplicate generated interface libraries are replaced. Runtime power,
  suspend, charging, and thermal behavior still require device validation.
- Preserve the A8D4 stock ABI closures for proprietary audio, TrustKernel
  KeyMint support, MediaTek TFLite, and `getgameserver`/pcap under distinct
  `_vendor.so` filenames. Rewrite only their proprietary `DT_NEEDED` edges;
  leave Lineage's source-built libraries at the standard sonames. This avoids
  duplicate install paths without forcing Android 15 vendor binaries onto
  potentially changed Android 16 internal ABIs. Validate audio, FBE/KeyMint,
  ML-dependent services, and the game-network helper on-device.
  Renamed ABI libraries must be generated as normal prebuilt Soong modules;
  do not retain `MAKE_COPY_RULE_ONLY` on those entries, because patched
  proprietary `DT_NEEDED` edges require resolvable `_vendor` module names.
- Use the source-built `android.system.wifi.keystore@1.0` HIDL interface
  library; retain and validate the proprietary `libkeystore-wifi-hidl.so`
  consumer.
- The clean `lineage-23.2` tree contains frozen Health and Boot AIDL snapshots
  whose `.aidl` files match the generated dumps byte-for-byte, but whose
  `.hash` metadata is rejected by the current AIDL equality checker. The build
  loop parses (but never shell-evaluates) failed AIDL commands, retries against
  temporary copies without `.hash`, and writes the failed `has_development`
  edge only after semantic `--checkapi=equal` succeeds. A real API mismatch
  remains fatal and the checked-in frozen API is never modified.
- The macOS source bind mount is case-insensitive. Because recovery `libvintf`
  adds `system/libvintf/include/vintf` to its include path, `<regex.h>` was
  incorrectly resolved to libvintf's own `Regex.h` instead of Bionic's POSIX
  header. The build preflight idempotently renames that wrapper to
  `PosixRegex.h` and updates its local includes; a case-sensitive checkout is
  left unchanged.
- Recovery boots on the A8D3 test tablet, but its first image exposed no ADB,
  sideload or fastbootd USB interface. The verified A8D4 stock ramdisk carries
  `init.recovery.mt8781.rc`, which selects configfs, the `musb-hdrc` UDC and
  synchronous FunctionFS. The Lineage ramdisk lacked this hardware rc entirely;
  the device tree now supplies the minimal observed three-property setup under
  both stock-provided hardware names, `mt8781` and `mt6789`, because recovery
  init selects the filename dynamically from `ro.hardware`.
- The dual-name recovery USB fix is validated on the physical A8D3 tablet:
  normal recovery ADB, ADB sideload and userspace fastbootd all enumerate on
  macOS. Recovery reports slot `_a`; fastbootd identifies product `t65max`
  and `is-userspace: yes`, but returns an empty `current-slot` value.
- Lineage fastbootd requires a Boot Control service in the recovery ramdisk;
  the stock vendor-only HIDL service is unavailable before logical partitions
  are mapped. Include AOSP's
  `android.hardware.boot-service.default_recovery`, which reads the verified
  `ro.boot.slot_suffix` and standard boot-control metadata from `misc`.
- The automated build always rsyncs the small device/kernel trees with
  preserved mtimes, but it fingerprints extraction scripts, blob lists, the
  captured blob manifest and blob metadata. It reuses the generated vendor
  tree while that fingerprint is unchanged, avoiding needless regeneration
  of 1,107 prebuilts and the resulting Soong invalidation. Soong's own short
  glob validation remains mandatory for correctness.
