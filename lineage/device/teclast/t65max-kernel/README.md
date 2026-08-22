# T65 Max A8D3 prebuilt kernel artifacts

These files were extracted from the verified A8D3 EEA stock package and are an
interim bring-up input, not kernel source.

```text
Image.gz SHA-256: 531cfbbce577fee26d9af8c6405d7540718bd6b0a4b9aad870924eca01770d42
DTB SHA-256:      cea1704acab52688d5d5f128470f1ad7a03a23c89dbf9223be1b4ad66d9d3d35
```

The vendor-ramdisk and vendor_dlkm modules are kept in separate directories
with their original load order. They must not be mixed with the A8D4 kernel or
modules. A publishable kernel repository ultimately requires the corresponding
Teclast/MediaTek GPL source and a reproducible configuration.
