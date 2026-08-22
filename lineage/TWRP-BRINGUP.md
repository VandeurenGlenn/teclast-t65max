# TWRP/recovery bring-up notes for Teclast T65 Max

## Verified layout

- Physical hardware: A8D3
- Working firmware base: official A8D4 ROW Android 15 `V1.07_20250603`
- Boot header: v4
- `boot_a`/`boot_b`: 64 MiB
- `vendor_boot_a`/`vendor_boot_b`: 64 MiB
- `dtbo_a`/`dtbo_b`: 8 MiB
- No separate `recovery` partition exists in the official scatter.
- `init_boot_a` and `init_boot_b` exist as 8 MiB partitions, but the A8D4
  package assigns no image and marks them non-downloadable.
- Stock recovery, its init files, recovery fstab, fastbootd and recovery kernel
  modules are carried through `vendor_boot`.

The device tree therefore enables recovery resources in `vendor_boot` and
uses the exact A8D4 `modules.load.recovery` list. A generic recovery image or a
TWRP built for another MT6789 tablet is not compatible merely because the SoC
matches.

## Grounded build inputs now available

- Official A8D4 kernel `5.10.218`
- A8D4 DT-table plus extracted entry 0 and redacted live DTS
- 196 A8D4 vendor-ramdisk kernel modules
- 205 A8D4 vendor_dlkm kernel modules
- Exact stock recovery fstab (byte-identical to the earlier A8D3 copy)
- Stock recovery init files and 189-entry recovery module load list
- Live kernel config from `/proc/config.gz`
- Dynamic-partition/super metadata and verified partition sizes
- Rooted VINTF, init and SELinux configuration capture

## Recommended test sequence

1. Build Lineage recovery first in a full Linux LineageOS checkout. This tests
   packing, kernel/DTB/modules, display, touch, USB/ADB, fstab and fastbootd
   with fewer TWRP-specific variables.
2. Unpack the generated images and compare their header-v4 fields, offsets,
   sizes and ramdisk placement against the official A8D4 images before any
   flash.
3. Keep the official A8D4 `boot.img`, `vendor_boot.img`, `dtbo.img` and vbmeta
   images ready for immediate MediaTek recovery.
4. Do not test by overwriting the working slot-A `vendor_boot` until a complete
   restore command has been rehearsed. Conventional bootloader fastboot has
   been unreliable on this tablet, so `fastboot boot` cannot be assumed.
5. Once Lineage recovery is proven, add TWRP-specific configuration and test
   display/touch, ADB, fastbootd and read-only mounting before attempting data
   decryption or writes.
6. Only enable userdata decryption after the TrustKernel KeyMint/FBE behavior
   is understood. The earlier Android 16 GSI failed while creating an FBE key;
   weakening encryption is not an acceptable published workaround.

## Current blockers

- No full Linux LineageOS/TWRP source checkout or build host is present here.
- Only about 5.5 GiB remains free on this Mac; a full build needs several
  hundred GiB of fast storage.
- Matching Teclast/MediaTek GPL kernel source is still missing. The prebuilt
  kernel is appropriate for initial recovery bring-up but not a final official
  LineageOS kernel solution.
- The 627-blob seed is captured, but 2,924 device-specific candidates still
  need dependency-driven curation.
- No Xiaomi blob fixup has been copied. Any future shim or binary fixup must be
  justified by an observed T65 Max build/runtime failure.

Nothing produced by the current scaffold is ready to flash yet.
