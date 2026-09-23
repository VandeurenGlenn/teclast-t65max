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
- Android U split `IRemotelyProvisionedComponent` out of the KeyMint AIDL
  library into `android.hardware.security.rkp` while preserving its C++ ABI.
  The A8D4 TrustKernel KeyMint service and `libkeymint_vendor.so` directly
  import that class, so extraction adds `android.hardware.security.rkp-V3-ndk.so`
  only to those two ELF files. Keep normal ELF checking enabled.
- The Linux Clang sparse checkout needs `clang-stable` in addition to the
  release compiler. For this local BP4A tree the Trusty dirgroup is pointed at
  the available `clang-r563880c`; downloading the unused historical compiler
  worktrees increased Soong scan cost without helping the T65 Max target.
- On the 24 GB Apple Silicon build host, an earlier 16 GB Colima VM was
  OOM-killed during unconstrained Soong analysis. The guarded build now uses a
  16 GB VM plus temporary VM swap and bounded Go memory, leaving enough RAM for
  macOS. This is a build-host workaround, not a device-tree validation result.
- Soong analysis of this checkout reached 21.6 GB resident memory and later
  twice OOM-killed `soong_build` near 14 GiB RSS after exhausting an 8 GiB
  swapfile in the 16 GiB VM. The automated build now bounds the Go heap with
  `GOMEMLIMIT=12GiB` and `GOGC=25`. Because Soong deliberately launches its
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
  `build/run-full-build-limited-macos.sh`. It builds `bacon` with ten jobs,
  a 16 GiB Go heap limit, six Soong Go workers, 12 GiB temporary VM swap, and
  a persistent bounded 12 GiB ccache on the VM's external-data disk. It
  refuses to start with less than 60 GiB free on the external build volume.
- The incremental `out/` tree lives on the separate 100 GiB ext4 Lima disk
  `t65max-out`. Its sparse backing file is
  on the internal SSD under
  `~/Library/Application Support/T65MaxLineage/lima/_disks/t65max-out`; the
  external Lima disk registry contains only a symlink to it. Inside the VM it
  mounts at `/mnt/lima-t65max-out`, and the source checkout's `out` is a symlink
  to `/mnt/lima-t65max-out/out`. The build preflight refuses to continue if
  that mount or symlink is absent, preventing accidental cache recreation on
  the nearly full external data disk. The Colima configuration helper restores
  the extra-disk attachment idempotently if Colima regenerates `lima.yaml`.
- Do not split `out/soong/.intermediates` across filesystems. Soong's `sbox`
  atomically renames generated files from `out/soong/.temp`; moving only the
  `external` subtree to the data disk makes that operation fail with
  `invalid cross-device link`. Keep both on the internal `out` ext4 disk.
  The build preflight now rejects this invalid layout before expensive work.
- Keep the bounded 12 GiB ccache outside `out`, at `$HOME/t65max/ccache` on
  the VM's external-data-backed ext4 disk. This preserves compiler hits while
  avoiding another 8-12 GiB of allocation in the scarce internal sparse
  `t65max-out` backing file.
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
- During the first full compile after Soong/Kati, Rosetta failed two concurrent
  Clang processes with `Failed to map AOT header: 12` while both the guest
  journal and macOS reported memory pressure. Treat this exact errno-12 case
  as transient host-memory exhaustion. The build loop now reuses the existing
  Ninja graph at six jobs (then four if necessary) and resets only Rosetta's
  reproducible `.aotcache`/`.flu` translation files. It does this only when no
  Android.bp, Android.mk, or make fragment is newer than that graph. Other
  failures and graph changes continue through the full correctness path.
- Rosetta's AOT daemon can also abort in `Translator.cpp` while translating
  the supplied x86_64 JDK. The visible symptom is a repeatable `Bus error` from
  `signapk.jar`, even for `java -version`, while other x86 host tools still
  work. Stopping only `rosettad` keeps stable on-demand Rosetta translation
  available; the same signing command then succeeds. The build loop recognizes
  this exact `signapk.jar`/`Bus error` pair, disables only the optional AOT
  cache daemon and resumes the guarded existing Ninja graph.
- The complete host-tool provisioning includes Ubuntu's `xxd` package. ADB's
  `bin2c_fastdeployagentscript` genrule invokes it directly. After repairing
  this exact missing-tool failure, the guarded fast path may reuse the existing
  Ninja graph because installing a host executable does not change that graph.
- The verified A8D4 kernel has `CONFIG_IKHEADERS=y`. Its exact embedded header
  archive is extracted from the checked A8D4 `Image.gz`, sanitized with
  Bionic's own header tool, and packaged behind the minimal
  `t65max-kernel-a8d4/kernel-headers` `headers_install` shim. This satisfies
  Lineage's generated kernel-header edge without mixing another device's
  kernel headers or pretending that a buildable kernel source tree exists.
  On the ARM64 VM, Lineage's final `clean_headers.sh` step must invoke Bionics
  sanitizer with AOSP's x86_64 Python, matching the supplied x86_64 libclang;
  the build preflight applies that host-compatibility patch idempotently.
- Keep `/.t65max-build.swap` active for the lifetime of the Linux VM. Never
  run `swapoff` from a host-side build cleanup trap: an SSH disconnect can
  leave Ninja running remotely, and the resulting swap evacuation caused the
  guest OOM killer to terminate Ninja on 2026-09-17.
- Every stock shared library deliberately installed under an `_vendor.so`
  destination must carry the proprietary-files `FIX_SONAME` argument. Its
  proprietary callers already receive matching `DT_NEEDED` rewrites; leaving
  the original SONAME causes Soong's ELF check to reject the renamed prebuilt.
- The A8D4 camera-3A `lib3a.ae.stat`, `lib3a.flash`,
  `lib3a.sensors.color`, and `lib3a.sensors.flicker` blobs directly import
  Android logging symbols without declaring `liblog.so`. Add that explicit
  `DT_NEEDED` during extraction; do not conceal the ABI defect with
  `allow_undefined_symbols`.
- Do not retain the A8D4 32/64-bit `libcodec2_hidl_plugin.so` prebuilts. They
  shadow Lineage 23.2's same-named source module, do not export its build-time
  headers, and lack the newer `FilterWrapper::getParamReflector()` ABI needed
  by the current HIDL utilities. No retained proprietary ELF has a direct
  `DT_NEEDED` edge to this plugin. Use Lineage's source-built plugin so its
  implementation and exported headers remain revision-coherent.
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
- The A8D4 `vendor/lib64/mt6789/libmnl.so` and
  `vendor/lib64/libmtk-ril.so` import the legacy libcutils
  `property_get`/`property_set` API without declaring `libcutils.so`.
  Add that dependency during extraction; a complete proprietary-ELF scan
  found no other blob with the same missing dependency.
- Lineage 23.2's current `libbase` removed the old non-template `Trim` and
  `Basename` string overloads and the string-based `WriteStringToFd` overload
  still imported by seven verified A8D4 blobs, including the stock sensors and
  USB HAL services. Keep current `libbase` and add
  only these three forwarding entry points in the source-built 32/64-bit
  `libt65max_libbase_compat` shim. Extraction adds that shim only to the seven
  ELF files proven by comparison against the built vendor `libbase` export
  tables; do not disable ELF checking or replace the complete platform library.
- Use the source-built `android.system.wifi.keystore@1.0` HIDL interface
  library; retain and validate the proprietary `libkeystore-wifi-hidl.so`
  consumer.
- Do not copy the resolved stock `<sepolicy><version>31.0</version>` block into
  the source device-manifest input. Lineage's `assemble_vintf` injects its
  current `BOARD_SEPOLICY_VERS` (`202504` in this checkout); retaining both
  values is rejected as an override. Keep the verified device and kernel
  target level 6 declarations. This XML-only repair can reuse the Ninja graph.
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
