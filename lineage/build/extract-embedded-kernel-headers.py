#!/usr/bin/env python3

import argparse
import io
import os
from pathlib import Path
import sys
import tarfile
import tempfile


XZ_MAGIC = b"\xfd7zXZ\x00"


def embedded_headers(image_gz: Path) -> tarfile.TarFile:
    import gzip
    import lzma

    with gzip.open(image_gz, "rb") as source:
        image = source.read()
    offset = 0
    while True:
        offset = image.find(XZ_MAGIC, offset)
        if offset < 0:
            raise RuntimeError("no embedded kernel header archive found")
        try:
            payload = lzma.LZMADecompressor().decompress(image[offset:])
            archive = tarfile.open(fileobj=io.BytesIO(payload), mode="r:")
            names = archive.getnames()
            if any(name.endswith("/include/uapi/linux/types.h") for name in names):
                return archive
            archive.close()
        except (lzma.LZMAError, tarfile.TarError):
            pass
        offset += len(XZ_MAGIC)


def source_mapping(name: str):
    name = name.removeprefix("./")
    mappings = (
        ("include/uapi/", "", ""),
        ("include/generated/uapi/", "", ""),
        ("arch/arm64/include/uapi/", "", "asm-arm64/"),
        ("arch/arm64/include/generated/uapi/", "", "asm-arm64/"),
    )
    for prefix, destination_prefix, clean_prefix in mappings:
        if name.startswith(prefix):
            relative = name[len(prefix):]
            return destination_prefix + relative, clean_prefix + relative
    return None


def deterministic_archive(root: Path, output: Path):
    import gzip

    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode="w") as archive:
                for path in sorted(root.rglob("*")):
                    relative = path.relative_to(root)
                    info = archive.gettarinfo(str(path), arcname=str(relative))
                    info.uid = info.gid = 0
                    info.uname = info.gname = "root"
                    info.mtime = 0
                    if path.is_file():
                        with path.open("rb") as source:
                            archive.addfile(info, source)
                    else:
                        archive.addfile(info)


def main():
    parser = argparse.ArgumentParser()
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--image", type=Path)
    source.add_argument("--archive", type=Path)
    parser.add_argument("--bionic-tools", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    bionic_tools = args.bionic_tools.resolve()
    os.environ.setdefault("ANDROID_BUILD_TOP", str(bionic_tools.parents[3]))
    sys.path.insert(0, str(bionic_tools))
    import clean_header

    archive = (tarfile.open(args.archive, mode="r:") if args.archive
               else embedded_headers(args.image))
    with tempfile.TemporaryDirectory(prefix="t65max-kheaders-") as temporary:
        temporary = Path(temporary)
        raw_root = temporary / "raw"
        output_root = temporary / "archive" / "usr" / "include"
        selected = {}
        for member in archive.getmembers():
            mapping = source_mapping(member.name)
            if not member.isfile() or mapping is None:
                continue
            destination, clean_relative = mapping
            selected[destination] = (member, clean_relative)

        for destination in sorted(selected):
            member, clean_relative = selected[destination]
            source_path = raw_root / destination
            source_path.parent.mkdir(parents=True, exist_ok=True)
            extracted = archive.extractfile(member)
            if extracted is None:
                continue
            source_data = extracted.read()
            source_path.write_bytes(source_data)
            destination_path = output_root / destination
            destination_path.parent.mkdir(parents=True, exist_ok=True)
            if not source_data.strip():
                destination_path.write_bytes(source_data)
                continue
            try:
                cleaned = clean_header.cleanupFile(
                    str(destination_path), str(source_path), clean_relative,
                    no_update=False
                )
            except Exception as error:
                raise RuntimeError(
                    f"failed to sanitize {member.name} -> {destination}"
                ) from error
            if cleaned:
                destination_path.write_text(cleaned)

        archive.close()
        required = output_root / "linux" / "types.h"
        if not required.is_file():
            raise RuntimeError(f"required header was not generated: {required}")
        deterministic_archive(temporary / "archive", args.output)

    print(f"wrote {args.output}")


if __name__ == "__main__":
    main()
