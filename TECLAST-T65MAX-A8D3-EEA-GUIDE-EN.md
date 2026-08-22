# Teclast T65 Max A8D3 EEA: Android/GSI guide for macOS

> Work in progress, tested on one `T65Max_EEA` with hardware/firmware revision `A8D3` and original stock ROM `V1.05_20260305` (Android 14). Bootloader unlocking is verified. The official A8D4 ROW Android 15 package was cross-flashed, completed first boot, and completed a subsequent normal reboot. Basic hardware functions were reported working on the test tablet, but exhaustive compatibility testing is still pending. Magisk root using the matching A8D4 `boot.img` is verified. An official Android 16 QPR2 GMS GSI was also tested earlier and did **not** complete first boot. TWRP has not been built or installed. Do not present the Android 16 steps or the A8D4 cross-flash as a generally safe procedure.

## Critical warnings

- Use this only with the **T65 Max A8D3 EEA**. Other hardware revisions or regions may require different preloader, download-agent, and partition files.
- Unlocking the bootloader and erasing `userdata`/`metadata` deletes all user data.
- Back up personal files and MediaTek calibration partitions before making changes.
- Never flash `preloader`, `nvram`, `nvdata`, `persist`, `proinfo`, `protect1/2`, `otp`, or `seccfg` from another device.
- Keep the complete official ROM available for recovery.
- Do not publish USB serial numbers, ME_ID, SOC_ID, or raw device-specific calibration images.

## Tested configuration

- Model: `T65Max_EEA`
- Revision: `A8D3`
- Stock build: `V1.05_20260305`
- Stock OS: Android 14 / API 34
- SoC: MediaTek MT6789/MT8781V (Helio G99)
- Architecture: ARM64
- Kernel: Android 12 GKI 5.10.198
- Project Treble: enabled
- A/B and Virtual A/B: enabled
- Dynamic partitions: enabled
- `super` partition: 9 GiB
- Vendor: Android 12 / VNDK 31
- AVB: 1.2
- Required GSI class: ARM64, A/B, system-as-root; commonly named `arm64-ab` or `arm64-b*`

The list above describes the original A8D3 EEA baseline. The currently tested
cross-flashed state is A8D4 ROW Android 15/API 35, security patch
`2025-04-05`, kernel `5.10.218`, vendor Android 12/API 31/VNDK 31, slot A,
bootloader unlocked, Magisk 30.7 rooted, and SELinux enforcing.

Android 16 is the sensible first target for this stock kernel/vendor combination. Android 17 QPR1 and newer no longer support the Android 12 5.10 kernel in the official Android kernel support matrix.

## Requirements on macOS

- A reliable USB data cable, preferably connected directly to the Mac
- Android Platform Tools (`adb` and `fastboot`)
- Python 3 and [mtkclient](https://github.com/bkerler/mtkclient)
- The official A8D3 EEA firmware
- Enough storage for personal and raw-partition backups

The official ROM used during this test was:

```text
T65Max(A8D3)_Android 14_V1.05_20260305_EEA_SZ.rar
SHA-256: 7f304ec93fd11c91a90d438b78e5a68102b8ae713b0cdf08d62d6d64bcd5939f
```

The following files from that ROM were used:

```text
Firmware/download_agent/DA_BR.bin
SHA-256: 7371562ba47111708da6508cb9ca239591b69577af95780f5de2a1db11c57456

Firmware/preloader_tb8781p1_64.bin
SHA-256: d93aa3609ba6762659dfd0bc7daa13373b3b75fbbc31edde8c9be27020865529
```

Always verify checksums before using the files.

## 1. Read and verify compatibility

Enable Developer options, OEM unlocking, and USB debugging. Then inspect the device:

```sh
adb devices -l
adb shell getprop ro.product.model
adb shell getprop ro.build.version.release
adb shell getprop ro.treble.enabled
adb shell getprop ro.boot.slot_suffix
adb shell getprop ro.virtual_ab.enabled
adb shell getprop ro.boot.dynamic_partitions
adb shell uname -a
```

Continue only when the model, revision, firmware, and partition layout match.

## 2. Create backups

First copy shared storage and record the installed third-party packages:

```sh
adb pull /sdcard ./backup/shared-storage
adb shell pm list packages -3 > ./backup/installed-third-party-packages.txt
```

ADB cannot read all protected application data. This is expected. Also use mtkclient to create separate raw backups of at least:

```text
seccfg nvcfg nvdata persist protect1 protect2 proinfo nvram
csci dram_para flashinfo otp sec1 lk_a lk_b
```

Create SHA-256 checksums. Never publish these raw images because they may contain device-specific data.

## 3. Connect reliably with mtkclient

For every command, use the DA and preloader from the same A8D3 EEA ROM. Example from inside the mtkclient directory:

```sh
python mtk.py \
  --loader /path/to/Firmware/download_agent/DA_BR.bin \
  --preloader /path/to/Firmware/preloader_tb8781p1_64.bin \
  gettargetconfig
```

A successful connection on the tested tablet reported:

```text
CPU: MT6789/MT8781V(MTK Helio G99)
Detected regular mode
SBC enabled: False
SLA enabled: False
DAA enabled: False
Device is unprotected
```

### Handshake timing for this tablet

Holding hardware buttons often produced `Handshake failed, retrying...`. The most reliable tested method was:

1. Start mtkclient and let it wait for the device.
2. Reboot the fully started tablet with `adb reboot`.
3. mtkclient catches the short PreLoader window during the reboot.

Read-only test example:

```sh
(sleep 3; adb reboot) & python mtk.py \
  --loader /path/to/DA_BR.bin \
  --preloader /path/to/preloader_tb8781p1_64.bin \
  gettargetconfig
```

If Android is not running, start mtkclient first, leave USB connected, hold Power for about 15 seconds, release it, and do not press a volume button.

## 4. Bootloader state through `seccfg`

This tablet did not expose usable conventional bootloader fastboot. `adb reboot bootloader` returned to Android. Fastbootd was available but reported `unlocked: no` and did not recognize the standard unlocking command.

After completing all backups, mtkclient was used to request a V4 lock-state change stored in `seccfg`. The tool reported:

```text
Detected V4 Lockstate
hwtype V4
Successfully wrote seccfg
```

This message alone did **not** prove a persistent unlock. After the factory reset, Android reported `ro.boot.flash.locked=1`, Verified Boot remained `green`, and fastbootd reported `unlocked: no`. A new raw dump of `seccfg` had exactly the same SHA-256 checksum as the original backup. The non-critical write had therefore been rejected or restored during boot.

The tested mtkclient commit `0542a8729993000661e2325e838217ee754d1632` changed V4 handling: the older behavior that also changes the dm-verity/critical-lock state now requires `--critical`. After separate informed consent, `da seccfg unlock --critical` generated the correct V4 structure (`lock_state=3`, critical state `1`) but the specialized XML extension still reported success without leaving persistent bytes.

The method that actually persisted on this tablet was:

1. Use that same tablet and the same verified A8D3 EEA loader to generate its own 512-byte critical-unlock structure. A local diagnostic patch saved mtkclient's generated `writedata` before the specialized write.
2. Verify that the candidate header contains V4 `lock_state=3` and critical state `1`.
3. Write that device-generated file with the ordinary partition writer:

   ```sh
   python mtk.py \
     --loader /path/to/DA_BR.bin \
     --preloader /path/to/preloader_tb8781p1_64.bin \
     w seccfg seccfg-unlock-candidate.bin
   ```

4. Start a new MediaTek session, dump the complete `seccfg` partition, and compare its first 512 bytes with the candidate.
5. Reboot and verify all three independent signals: the orange boot warning, Android `ro.boot.flash.locked=0`/`ro.boot.vbmeta.device_state=unlocked`, and fastbootd `unlocked: yes`.

On the tested unit the candidate/readback SHA-256 was `397faa88b92cb85aa0dc99cc6fcfd16fbce456b1596b6191cb209c7311140e5f`. **This file is device-specific: never flash this hash's corresponding file to another tablet. Each device must generate and validate its own cryptographic structure.**

## 5. Erase `userdata` and `metadata`

After explicit approval, the following was used on the tested tablet:

```sh
python mtk.py \
  --loader /path/to/DA_BR.bin \
  --preloader /path/to/preloader_tb8781p1_64.bin \
  e userdata,metadata
```

The partitions were also handled separately because the MediaTek XML DA waited indefinitely for its final USB response. The log reached:

```text
userdata: 100% Erasing
metadata: Formatting ... length 0x2000000
metadata: 100% Erasing
```

Important: processing reached 100%, but mtkclient did not always receive a clean final status. This behaved as a device/DA quirk. Successful erasure was subsequently confirmed when stock recovery performed its factory reset and Android reached the initial Welcome screen.

After the direct erase, stock recovery may show:

```text
Cannot load Android system. Your data may be corrupt.
```

Select `Factory data reset`, confirm it, and then select `Reboot system now`. Android will recreate its filesystem and encryption metadata correctly. The first boot can take 5–10 minutes.

## 6. Android 16 QPR2 GSI test: flashed but not bootable

The official Google ARM64+GMS image tested was:

```text
gsi_gms_arm64-exp-BP4A.251205.006-14401865-f8760221.zip
ZIP SHA-256: f87602213d71f1eda90cbd3e6089cea28563d110e4ef3f70b748b2b111d4ecce

system.img
SHA-256: f84a70818343b336004c900a98194139ca210e7ad24bdd1af89b55db28b629e8
```

The tablet was in fastbootd on slot B. `system_b` was erased and the raw ext4 GSI was flashed successfully. The partition was automatically resized and all 13 chunks completed without a fastboot error.

This MediaTek fastbootd does not expose physical `vbmeta_b`, so `fastboot --disable-verity --disable-verification flash vbmeta_b ...` cannot open that partition. The tablet's own `vbmeta_b` was therefore read with mtkclient, patched to AVB flags `3`, written back, and verified byte-for-byte. The chained `vbmeta_system_b` still contained the Android 14 `system` hash and flags `0`; it was separately backed up, patched to flags `3`, written, and also verified byte-for-byte. Do not distribute either patched image because it was derived from one specific tablet.

AVB was not the cause of the first Android-userspace failure. The MediaTek crash-log partition recorded:

```text
[AVB] img_auth_required = 0
[AVB] avb_ret = 0
vold: keystore2 Keystore generateKey returned service specific error: -49
vold: read_key failed in mountFstab
init: [libfs_mgr] Encryption failed
```

Android defines Keymaster/KeyMint error `-49` as `SECURE_HW_COMMUNICATION_FAILED`. The GSI reached Android `init`, mounted `/system`, and started APEX processing, but the stock MediaTek Keymaster/TEE path could not create the key required by the stock userdata fstab. Recovery consequently returned to `Try again / Factory data reset`; repeating a factory reset did not fix it.

The stock `vendor_boot.img` confirms that `/data` is F2FS with file-based encryption and a metadata key directory:

```text
fileencryption=aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized
keydirectory=/metadata/vold/metadata_encryption
```

A temporary slot-B test then removed file-based encryption from the stock fstab and used a correspondingly modified vendor image. This bypassed the original encrypted-data failure far enough to reach the Android boot animation, but Android still never completed first boot. A current crash log could not be captured during that later hang, so its exact final blocker is not proven. Although the stock user-visible OS and framework are Android 14, the stock vendor partition identifies itself as Android 12/API 31 (`ro.vendor.build.version.release=12`, `ro.vendor.build.version.sdk=31`, `ro.vndk.version=31`). Likely remaining compatibility boundaries therefore include this Android 12-era vendor stack underneath Android 14, MediaTek KeyMint/TEE services, OEM `product`/`system_ext` components, and SELinux policy. The no-FBE files were later removed; this insecure workaround is not a supported installation method.

### What is proven about the failed GSI

- The Android 16 GSI itself was transferred correctly and started Android userspace.
- AVB on the experimental slot was deliberately disabled and verified; it was not the first blocker.
- The first reproducible failure was stock file-based-encryption key creation through MediaTek KeyMint/TEE.
- Removing FBE changed the failure mode and reached the boot animation, proving that FBE was one blocker but not the only blocker.
- The final boot-animation hang was not diagnosed conclusively. Building a reliable ROM therefore still requires device/vendor integration work, SELinux logs and rules, proprietary blobs, and a suitable kernel/GKI configuration; root alone does not provide those automatically.

## 7. Stock recovery post-mortem

Restoring only stock logical partitions to slot B did not recover the tablet. The official A8D3 scatter package is laid out for slot A, so the complete official `super.img` was restored and slot A was selected. Recovery then reported that `/metadata` could not be mounted or formatted with `Invalid argument`.

The stock fstab proves that `/metadata` must be a 32 MiB ext4 filesystem, while `/data` is F2FS and stores its encryption key under `/metadata/vold/metadata_encryption`. A clean 32 MiB ext4 metadata image was created locally, checked with `e2fsck`, flashed to `metadata`, and followed by a recovery factory reset. This fixed the metadata-format error but did not yet fix the early Teclast-logo boot loop.

A MediaTek readback then proved that all four physical slot-A verification images differed from the official ROM:

```text
dtbo_a
vbmeta_a
vbmeta_system_a
vbmeta_vendor_a
```

They were restored individually with the official A8D3 EEA DA and preloader configuration. The preloader partition itself was not flashed. A second readback was compared against the official files; the complete `dtbo_a` image and the exact official-length prefixes of all three vbmeta partitions produced matching SHA-256 hashes. After restoring official `boot_a` and `vendor_boot_a`, selecting slot A again, and clearing its `unbootable` state, stock Android 14 booted successfully.

This proves the cause of the stock recovery loop: slot A was not actually a complete matching stock boot chain until its physical dtbo/vbmeta partitions were restored. It does **not** prove that those physical slot-A differences caused the original slot-B GSI animation hang; those are separate failures.

## 8. Still to be tested and documented

The following work is not complete and must not yet be shared as a proven procedure:

- Resolve the Android 16/MediaTek Keymaster userdata-encryption failure without weakening security if possible
- Test the first boot, mobile network, camera, audio, sleep, and other hardware
- Root using a Magisk-patched copy of this device's own `init_boot` or `boot` image
- Build or verify a device-specific TWRP; do not install an arbitrary TWRP image

## 9. A8D4 Android 15 ROW firmware analysis

The official Teclast archive examined for a possible cross-revision test was:

```text
T65Max(A8D4)_Android 15_V1.07_20250603_ROW_SZ.rar
SHA-256: d19df1446f31bba001bb7259e580a25ec0916859391084bee73d6f99afc27edf
```

This is an **A8D4 ROW** package, not an A8D3 EEA update. Its system image is Android 15/API 35 with security patch `2025-04-05`. Static inspection produced several useful results:

- The A8D3 and A8D4 `MT6789_Android_scatter.txt` files are byte-identical. Their physical partition names, offsets, and sizes therefore match.
- A8D4 does **not** provide a newer Treble vendor generation. Its vendor still reports Android 12/API 31 and VNDK 31, just like A8D3.
- A8D4 does contain a newer Android 12 GKI kernel: `5.10.218`, compared with the examined A8D3 boot image's `5.10.198` kernel.
- The A8D4 vendor ramdisk uses the same `fstab.mt8781` and the same FBE/metadata-encryption configuration as A8D3. It therefore does not directly solve the proven KeyMint error `-49` from the Android 16 GSI test.
- The loaded panel/touch module names are substantially the same, which is encouraging but does not prove that every A8D3 display, touch, camera, modem, sensor, and power-management component is compatible.
- The A8D4 boot, vendor_boot, dtbo, vbmeta images, kernel modules, and preloader all differ from A8D3. The A8D4 AVB metadata forms one matching chain for its own Android 15 logical partitions.
- The A8D3 vendor package is dated March 2026, while the examined A8D4 package is dated June 2025. A8D4 has the newer Android framework and kernel, but is not simply newer in every component.

Consequently, installing A8D4 Android 15 would be an experimental **cross-revision/region flash**, not a vendor upgrade proven to fix GSI compatibility. A full second copy cannot coexist with the working A8D3 logical partitions: the two complete stacks total roughly 12 GiB while `super` is only 9 GiB. Virtual A/B does not provide two independently populated 9 GiB super partitions. A real A8D4 test must therefore overwrite the current logical A8D3 stack (or use an equally invasive custom repack), even if physical boot-chain slots are retained.

Do not mix arbitrary A8D3 and A8D4 boot-chain components, and do not flash the A8D4 preloader. A complete verified recovery path using the original A8D3 EEA ROM must remain available. The exact minimum safe physical-firmware set required by A8D4 is not proven; this is another reason not to treat the package as a routine update.

### A8D3-to-A8D4 cross-flash result on the test tablet

The cross-flash was subsequently performed on the same A8D3 EEA test tablet. The official A8D4 `super.img` and matching slot-A Android boot chain (`boot_a`, `vendor_boot_a`, `dtbo_a`, `vbmeta_a`, `vbmeta_system_a`, and `vbmeta_vendor_a`) were written first. Userdata and metadata were reset using stock recovery. That partial installation repeatedly returned to the recovery data-reset screen.

A binary comparison proved that the following A8D4 physical firmware images all differed from A8D3. They were written to slot A individually, using the trusted A8D3 download agent and A8D3 preloader file only as the MediaTek DRAM/download loader:

```text
lk_a
tee_a
gz_a
md1img_a
spmfw_a
pi_img_a
dpm_a
scp_a
sspm_a
mcupm_a
```

Android 15 first completed boot after the first five images in that list had been updated. The remaining five were then updated to avoid retaining a mixed A8D3/A8D4 power-management and coprocessor firmware stack. All ten MediaTek writes ended with an explicit `Wrote ...` confirmation. This identifies the incomplete physical-firmware stack as the practical cause of the A8D4 recovery loop, but it does not isolate one single image as the minimum fix.

The A8D4 preloader was **not** flashed. NVRAM, NVDATA, protect, calibration, and device-identity partitions were not modified during the cross-flash. The original A8D3 EEA ROM, trusted A8D3 recovery set, and complete A8D4 firmware were retained locally. The large device-specific backup set was deleted only after the successful Android 15 boot, at the owner's explicit request.

Result so far: the A8D3 EEA test tablet reached the A8D4 ROW Android 15 user interface and subsequently completed a normal Android reboot. Basic hardware functions were reported working by the owner. This is not yet a complete compatibility certification; each subsystem and a full power-off/cold boot should be recorded explicitly before publishing a repeatable end-user procedure.

### Verified Magisk root on A8D4 Android 15

The A8D4 scatter declares `init_boot_a`, but assigns it no image (`file_name: NONE`, `is_download: false`). Root was therefore installed by patching the exact official A8D4 `boot.img`, not an `init_boot` or an image from another firmware revision.

The official Magisk v30.7 APK was installed, the stock A8D4 boot image was copied to the tablet, and Magisk produced a 64 MiB patched Android boot image. The tested files were:

```text
stock A8D4 boot.img SHA-256:
01d606f235c65dfab10109cd561693e9e5bd47722157c75b9d47960cfde932a7

Magisk-patched boot image SHA-256:
85282f5e70ff6ba5007acbe6cf9d7400148bb41a39bf8dde4613f697a3a237b4
```

Only `boot_a` was written, using the trusted A8D3 DA and A8D3 preloader file as the download/DRAM loader. No additional vbmeta or AVB change was made for root. Android 15 completed boot, then retained root across a separate normal reboot. The following checks succeeded after that reboot:

```text
sys.boot_completed=1
Magisk 30.7 (30700)
uid=0(root) gid=0(root) groups=0(root) context=u:r:magisk:s0
SELinux: Enforcing
```

Keep the exact official A8D4 `boot.img`. If the patched image fails, write that stock image back to `boot_a` using the same trusted MediaTek method. Never reuse the published patched-image hash as if the corresponding file were universal: Magisk output may vary, and every user should patch the boot image from the exact firmware installed on their own tablet.

TWRP remains uninstalled. A random MediaTek or T65 Max recovery must not be flashed; recovery needs to be built and validated against this device's A8D4 boot/recovery layout, kernel, fstab, dynamic partitions, and encryption setup.

### Rooted LineageOS/TWRP bring-up capture

After root was verified, a privacy-conscious capture collected the matching
A8D4 kernel config, runtime device tree, partition and super metadata, active
HAL/service lists, module state, fstab/VINTF/init/SELinux configuration, and
local-only diagnostic logs. No userdata, calibration partition or device
identity partition was copied.

The rooted inventory contains 8,507 vendor paths, 512 product paths and 658
system_ext paths. A stock-grounded MT6789 category intersection selected 627
initial proprietary blobs; all 627 existed, were non-empty and were extracted
from the Teclast A8D4 system (326 MiB total). No Xiaomi binary was used. The
unreviewed 2,924 device-specific candidates remain an analysis list and were
not copied wholesale into the build manifest.

The exact A8D4 prebuilt bring-up set is now recorded as kernel 5.10.218, its
DT-table/DTB, 196 vendor-ramdisk modules, 205 vendor_dlkm modules and the live
kernel configuration. Recovery resources and the stock recovery module list
are configured for `vendor_boot`, matching the header-v4 recovery layout.

## Recovery strategy

If the tablet fails to boot:

1. Stop flashing unrelated images.
2. Use only the official A8D3 EEA ROM and its matching scatter, DA, and preloader.
3. Restore the stock boot-critical images (`boot`, `vendor_boot`, and `vbmeta*`) according to the official partition layout.
4. Restore calibration partitions only from that same tablet's own backup.
5. Never flash a preloader from a different revision.

## Current test status

- Compatibility analysis: complete
- Official recovery ROM secured and hashes checked: complete
- Shared storage and critical partitions backed up: complete
- Ordinary and specialized XML `seccfg` writes were diagnosed; the device-generated critical structure persisted when written with generic `w seccfg`
- Stock Android 14 `V1.05_20260305` restored to slot A and booted successfully: verified complete
- Clean 32 MiB ext4 `metadata` filesystem plus recovery factory reset: verified complete
- Official `boot_a`, `vendor_boot_a`, `dtbo_a`, `vbmeta_a`, `vbmeta_system_a`, and `vbmeta_vendor_a`: restored; physical dtbo/vbmeta readbacks hash-verified
- Bootloader after reboot: verified unlocked by orange warning, Android properties, and fastbootd `unlocked: yes`
- Android 16 QPR2 GMS GSI: initial FBE boot failed with KeyMint/TEE error `-49`; a temporary no-FBE test reached the boot animation but never completed first boot
- Experimental slot-B AVB modifications and no-FBE files are not a supported final configuration
- Root: verified with Magisk 30.7 by patching the official A8D4 `boot.img` and writing only `boot_a`; Android booted and `su -c id` returned `uid=0(root)` while SELinux remained enforcing
- TWRP: not built or installed
- A8D4 Android 15 ROW: cross-flashed to the A8D3 EEA test tablet, reached Android successfully, and completed a normal reboot after the matching slot-A physical firmware stack was completed; full hardware and cold-boot testing remain pending. It still retains an Android 12/API 31/VNDK 31 vendor baseline
- Post-boot ADB baseline: captured with SELinux enforcing; no `avc: denied`, Java fatal exception, or native fatal signal was found in the first bugreport. VINTF manifests and vendor init configuration were saved locally for LineageOS bring-up
