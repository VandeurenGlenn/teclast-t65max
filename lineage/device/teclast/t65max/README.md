# LineageOS bring-up for Teclast T65 Max A8D3 hardware

This is an early, non-booting device-tree scaffold for A8D3 hardware. The
verified bring-up base is the official A8D4 ROW Android 15 stack
`V1.07_20250603`, cross-flashed onto the A8D3 test tablet. It targets LineageOS
23.x. The A8D3 Android 14 EEA package remains the recovery reference.

## Verified baseline

- MediaTek MT6789 / MT8781V, ARM64 with 32-bit compatibility
- Android 12 shipping vendor, API 31 and VNDK 31
- Android 12 GKI 5.10.218, boot header v4
- Dynamic partitions and Virtual A/B
- 9 GiB `super`, 64 MiB `boot`, 64 MiB `vendor_boot`, 8 MiB `dtbo`
- F2FS userdata and ext4 metadata with file-based encryption
- Stock SELinux enforcing

## Source policy

- The successfully booted A8D4 stock stack defines the current userspace,
  kernel, DTB, module and proprietary-blob contract.
- The physical tablet remains A8D3 hardware; the A8D4 preloader was not
  flashed and calibration/identity partitions remain device-original.
- The Xiaomi Redmi Pad `yunluo` MT6789 trees are reference implementations,
  not a source of flashable Teclast firmware.
- A8D3/A9D5 files must not be mixed into the A8D4 bring-up tree without
  file-level ABI and hardware validation.
- Device-specific calibration partitions and identifiers must never be added.

## Milestones

1. Produce a complete reproducible proprietary-file inventory.
2. Import the exact stock kernel, DTB and matching kernel modules.
3. Reconcile stock VINTF declarations with LineageOS 23.x interfaces.
4. Reach recovery and fastbootd without touching the working stock slot.
5. Reach an enforcing userspace boot, then validate radio, camera, audio,
   display, touch, sensors, encryption and suspend.
6. Only after the device meets the LineageOS charter, split this work into
   public device, vendor and kernel repositories and submit it for review.

Nothing in this directory is ready to flash.
