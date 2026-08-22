# T65 Max A8D3 hardware / A8D4 stack LineageOS bring-up status

## Target

- Product: Teclast T65 Max, currently reporting `T65Max_ROW`
- Hardware revision: A8D3
- Device codename used by this tree: `t65max`
- Target branch: LineageOS 23.x / Android 16
- Stock blob base: A8D4 ROW `V1.07_20250603` Android 15, verified booting on
  the A8D3 test tablet
- Recovery base: A8D3 EEA `V1.05_20260305` Android 14
- Vendor compatibility base: Android 12, API 31, VNDK 31

## Completed locally

- Captured a rooted, privacy-conscious A8D4 runtime snapshot containing
  selected properties, mounts, partition/super metadata, active HALs, kernel
  modules, kernel config, runtime device tree, SELinux state and local-only
  diagnostic logs.
- Imported the exact A8D4 `Image.gz`, DTB, 196 vendor-ramdisk modules and 205
  vendor_dlkm modules into a matched prebuilt-kernel tree.
- Imported the stock first-stage fstab and VINTF declarations.
- Created an initial LineageOS device-tree skeleton with the verified physical
  partition sizes and dynamic-partition layout.
- Generated deterministic rooted A8D4 file inventories:
  - vendor: 8,507 entries
  - product: 512 entries
  - system_ext: 658 entries
- Generated a 627-blob seed list by intersecting the public Redmi Pad MT6789
  proprietary-file categories with files that actually exist in A8D4 stock.
  This uses the Redmi tree only as a list/porting reference; all binary content
  must come from the matching Teclast A8D4 stack.
- Added standard LineageOS extract-utils entry points without inheriting any
  Xiaomi binary fixups. Fixups will be added only for observed T65 Max errors.
- Captured 780 vendor/ODM files actually mapped by live stock processes. Of
  these, 440 were absent from the initial MT6789 reference-derived seed.
- Merged those runtime-observed files and completed iterative ELF `DT_NEEDED`
  closure against all captured stock partition inventories. The closure added
  40 libraries; its final pass covered 926 ELF files with no further stock
  additions, ambiguous matches or objdump failures.
- Pulled the resulting 1,107-entry, 455 MiB set from rooted A8D4 stock and
  generated a deterministic 1,107-entry SHA-256 manifest.
- Magisk 30.7 root survives a normal reboot while SELinux remains enforcing.
- No `avc: denied` entry was present in the post-root capture.
- The device owner manually verified the stock A8D4 baseline functions,
  including display/touch, connectivity, cameras, audio, sensors, cellular,
  GNSS, charging, suspend/resume, DRM/media and cold boot.
- XML and Python helper validation pass.

## Important findings

- The stock device manifest declares target level 6 and includes dual-SIM
  radio, MediaTek camera/audio/display services and TrustKernel KeyMint.
- The proven Android 16 GSI failure occurred in the stock TrustKernel KeyMint
  path while creating the userdata FBE key. The Redmi Pad tree contains newer
  LineageOS-side KeyMint compatibility fixups, which are useful references but
  are not yet validated for the Teclast TrustKernel service.
- A source-built kernel is not available yet. The prebuilt 5.10 kernel is
  sufficient for early bring-up, but official LineageOS submission ultimately
  needs a maintainable, redistributable kernel solution.

## Next engineering work

1. Run the extract-utils scripts inside a full LineageOS checkout and generate
   the vendor makefiles from the locally captured Teclast blobs.
2. Reconcile LineageOS 23.x framework matrices with the stock level-6 VINTF
   contract and implement only the necessary blob fixups/shims.
3. Produce recovery and boot images in a full LineageOS source checkout.
4. Test recovery first, then an enforcing system build, keeping a full stock
   recovery path throughout.
5. Validate every LineageOS device-support requirement before requesting
   official inclusion.

## Build-host constraint

The earlier Git-garbage cleanup restored about 222 GiB of free host storage.
That is sufficient for device-tree development, blob analysis and local
archives, but a complete LineageOS checkout/build still needs a supported
64-bit Linux environment and more comfortable build-space headroom. The
resulting device-specific trees can remain version-controlled here.
