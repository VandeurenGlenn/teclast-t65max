# Teclast T65 Max GSI compatibility report

Read from the connected tablet over ADB on 2026-08-17. The USB serial number is intentionally omitted.

## Device

- Model: `T65Max_EEA`
- Hardware revision: `A8D3` (derived from firmware `V1.05_20260305`)
- SoC/platform: MediaTek `MT6789` / `mt8781`
- CPU ABI: `arm64-v8a` with 32-bit app compatibility
- Installed Android: 14 / API 34
- Security patch: 2024-06-05
- Kernel: Android 12 GKI 5.10.198, arm64
- SELinux: Enforcing

## GSI-relevant properties

- Project Treble: enabled
- System-as-root: yes
- Partition scheme: A/B
- Current slot: B
- Virtual A/B: enabled
- Dynamic partitions: enabled
- Super partition: present
- System filesystem: ext4
- Vendor version: Android 12 / API 31
- VNDK version: 31
- Product first API level: 34
- AVB: 1.2
- Bootloader tijdens de oorspronkelijke inspectie: locked
- Verified Boot tijdens de oorspronkelijke inspectie: green
- OEM unlocking permitted by Android: yes (`sys.oem_unlock_allowed=1`)

## Correct image class

The hardware requires a 64-bit ARM, A/B, system-as-root GSI. In common community naming this is an `arm64-ab` or `arm64-b*` image. A standard ext4 image is the safest starting point. Do not use ARM32, A-only, x86, or a device-specific image for another T65 Max revision.

## Assessment

The tablet meets the structural requirements for a GSI. Android 16 is the recommended first target because its supported-kernel matrix still includes Android 12 kernel 5.10. Android 17 QPR1 and later no longer support Android 12 kernel 5.10, so Android 17 is not a sound first target on this stock boot/vendor stack.

Before flashing, obtain the complete A8D3 EEA recovery firmware, back up user data and critical MediaTek calibration partitions, and unlock the bootloader. Unlocking erases user data.

## Later procedure status (2026-08-18)

- The official A8D3 EEA recovery ROM and its loader/preloader were verified.
- User storage and 15 critical MediaTek partitions were backed up.
- The specialized mtkclient XML `seccfg` path reported successful non-critical and critical writes, but neither persisted. A device-generated 512-byte critical V4 structure was then written with generic `w seccfg` and verified by raw readback.
- `userdata` and `metadata` each reached 100% in the XML-DA erase operation. Stock recovery then completed its factory reset and Android reached the initial Welcome screen, confirming successful recreation of the data partitions.
- Android now reports `ro.boot.flash.locked=0`, Verified Boot `orange`, and `ro.boot.vbmeta.device_state=unlocked`; fastbootd independently reports `unlocked: yes`. The tablet also displayed the orange unlocked-bootloader warning and booted normally.
- No GSI, Magisk image, or TWRP image has been flashed yet.

See `TECLAST-T65MAX-A8D3-EEA-GUIDE-EN.md` for the shareable English guide and `TECLAST-T65MAX-A8D3-EEA-GUIDE-NL.md` for the Dutch work log.
