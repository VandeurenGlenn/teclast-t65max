# T65 Max A8D4 prebuilt kernel artifacts

These files were extracted from the official A8D4 ROW Android 15 package and
the rooted, successfully booted test tablet. They are an interim bring-up
input, not kernel source.

```text
Image.gz SHA-256:     02b6ad11953b4693507ca0415a74680ed008ddd27a7aeaeba830881acc4df3bc
DTB SHA-256:          61e56eeba4c43485fc490567254217aab0256f4dfdf6d338e2843c28e543c782
kernel.config SHA-256: 5e00896214ef26212042bd511689e205e1fa00229588fa67c1a6b178cc44ecd4
```

- Kernel release: `5.10.218-android12-9-00025-g7e8d2909ab18-ab12292143`
- Vendor-ramdisk modules: 196 files; stock load list contains 175 entries
- Vendor_dlkm modules: 205 files; stock load list contains 185 entries
- The live rooted capture reported 361 currently loaded modules

The kernel, DTB and modules must be treated as one matched A8D4 set. A
publishable kernel repository ultimately requires corresponding GPL source and
a reproducible configuration.
