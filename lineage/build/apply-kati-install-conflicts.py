#!/usr/bin/env python3
"""Apply audited T65 Max fixes for known Kati duplicate install targets."""

from __future__ import annotations

import argparse
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

CONFLICT_RE = re.compile(
    r"overriding commands for target `out/target/product/[^/]+/(?P<target>[^']+)'"
)
INSTALL_RULE_RE = re.compile(
    r"^out/target/product/[^/]+/(?P<target>[^:]+):", re.MULTILINE
)
SOURCE_INTERFACE_RE = re.compile(
    r"^vendor/lib(?:64)?/(?:android\.(?:frameworks|hardware|hidl|system)\.)[^/]+@[0-9][^/]*\.so$"
)
SOURCE_CODEC2_RE = re.compile(
    r"^vendor/lib(?:64)?/(?:"
    r"libcodec2_hidl@1\.[012]|"
    r"libcodec2_soft_common|"
    r"libcodec2_vndk|"
    r"libsfplugin_ccodec_utils|"
    r"libstagefright_bufferpool@2\.0\.1"
    r")\.so$"
)
SOURCE_TRANSPORT_RE = re.compile(
    r"^vendor/lib(?:64)?/(?:libdrm|libhwbinder|libhidltransport)\.so$"
)
SOURCE_MEDIA_CODEC_RE = re.compile(
    r"^vendor/lib(?:64)?/(?:"
    r"libopus|"
    r"libstagefright_amrnb_common|"
    r"libstagefright_enc_common|"
    r"libstagefright_flacdec|"
    r"libstagefright_softomx|"
    r"libstagefright_softomx_plugin|"
    r"libvorbisidec"
    r")\.so$"
)
SOURCE_MTKPOWER_INTERFACE_RE = re.compile(
    r"^vendor/lib(?:64)?/vendor\.mediatek\.hardware\.mtkpower@1\.[012]\.so$"
)

# These are deliberately explicit. An unknown duplicate is not safe to remove
# automatically because a stock blob may implement a device-specific ABI.
DROP_REPLACED_BY_SOURCE = {
    "vendor/etc/init/wlan_assistant.rc",
    "vendor/lib/libavservices_minijail.so",
    "vendor/lib64/hw/android.hardware.health@2.0-impl-2.1.so",
}

KEYMINT_RENAMES = {
    "vendor/lib64/lib_android_keymaster_keymint_utils.so":
        "vendor/lib64/lib_android_keymaster_keymint_utils_vendor.so",
    "vendor/lib64/libkeymint.so": "vendor/lib64/libkeymint_vendor.so",
}

AUDIO_RENAMES = {
    f"vendor/lib64/{name}.so": f"vendor/lib64/{name}_vendor.so"
    for name in (
        "android.hardware.audio.common-util",
        "audioclient-types-aidl-cpp",
        "framework-permission-aidl-cpp",
        "libalsautils",
        "libaudioclient_aidl_conversion",
        "libaudiofoundation",
        "libeffectsconfig",
        "libshmemcompat",
        "libshmemutil",
        "shared-file-region-aidl-cpp",
    )
}

KEYMINT_SUPPORT_RENAMES = {
    f"vendor/lib64/{name}.so": f"vendor/lib64/{name}_vendor.so"
    for name in (
        "libcppbor_external",
        "libcppcose_rkp",
        "libkeymaster_messages",
        "libkeymaster_portable",
        "libpuresoftkeymasterdevice",
        "libsoft_attestation_cert",
    )
}

TFLITE_SUPPORT_RENAMES = {
    f"vendor/lib64/{name}.so": f"vendor/lib64/{name}_vendor.so"
    for name in ("libflatbuffers-cpp", "libruy", "libtextclassifier_hash")
}

PCAP_RENAMES = {
    "vendor/lib64/libpcap.so": "vendor/lib64/libpcap_vendor.so",
}

STOCK_ABI_RENAME_GROUPS = (
    KEYMINT_RENAMES,
    AUDIO_RENAMES,
    KEYMINT_SUPPORT_RENAMES,
    TFLITE_SUPPORT_RENAMES,
    PCAP_RENAMES,
)


def parse_entry(line: str) -> tuple[str, str, str, str] | None:
    match = re.match(
        r"^(?P<prefix>-?)(?P<src>[^:;|]+)(?::(?P<dst>[^;|]+))?(?P<extras>.*)$",
        line.rstrip("\n"),
    )
    if not match:
        return None
    return (
        match.group("prefix"),
        match.group("src"),
        match.group("dst") or match.group("src"),
        match.group("extras"),
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", type=Path)
    parser.add_argument("--blob-list", type=Path, required=True)
    parser.add_argument("--audit-log", type=Path, required=True)
    parser.add_argument("--round", required=True)
    parser.add_argument("--installs-mk", type=Path)
    parser.add_argument("--normalize-renames", action="store_true")
    args = parser.parse_args()

    lines = args.blob_list.read_text().splitlines(keepends=True)
    entries: list[tuple[str, str, str, str]] = []
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        parsed = parse_entry(line)
        if parsed is not None:
            entries.append(parsed)

    rename_destinations = {
        destination
        for group in STOCK_ABI_RENAME_GROUPS
        for destination in group.values()
    }
    if args.normalize_renames:
        output: list[str] = []
        changes: list[tuple[str, str, str]] = []
        for line in lines:
            parsed = parse_entry(line)
            if parsed is None:
                output.append(line)
                continue
            prefix, src, dst, extras = parsed
            newline = "\n" if line.endswith("\n") else ""
            if dst in rename_destinations and "MAKE_COPY_RULE_ONLY" in extras:
                extras = re.sub(r";MAKE_COPY_RULE_ONLY(?=;|\||$)", "", extras)
                changes.append(("generate-renamed-prebuilt", src, dst))
                output.append(f"{prefix}{src}:{dst}{extras}{newline}")
            else:
                output.append(line)
        if changes:
            args.blob_list.write_text("".join(output))
            args.audit_log.parent.mkdir(parents=True, exist_ok=True)
            timestamp = datetime.now(timezone.utc).isoformat()
            with args.audit_log.open("a") as audit:
                for action, src, dst in changes:
                    audit.write(f"{timestamp}\t{args.round}\t{action}\t{src}\t{dst}\n")
            print(f"normalized {len(changes)} renamed prebuilt module(s)", flush=True)
        return 0

    if args.log is None:
        parser.error("--log is required unless --normalize-renames is used")

    reported_conflicts = set(CONFLICT_RE.findall(args.log.read_text(errors="replace")))
    conflicts = set(reported_conflicts)

    # Kati reports only its first duplicate. Once Soong has generated the full
    # install list, find every copy-only stock entry that already has a source
    # producer so all safe interface replacements are handled in one round.
    if args.installs_mk and args.installs_mk.exists():
        install_targets = set(
            INSTALL_RULE_RE.findall(args.installs_mk.read_text(errors="replace"))
        )
        conflicts.update(
            dst
            for _prefix, _src, dst, extras in entries
            if "MAKE_COPY_RULE_ONLY" in extras and dst in install_targets
        )

    if not conflicts:
        return 10

    safe_source_replacements = {
        target
        for target in conflicts
        if target in DROP_REPLACED_BY_SOURCE
        or SOURCE_INTERFACE_RE.match(target)
        or SOURCE_CODEC2_RE.match(target)
        or SOURCE_TRANSPORT_RE.match(target)
        or SOURCE_MEDIA_CODEC_RE.match(target)
        or SOURCE_MTKPOWER_INTERFACE_RE.match(target)
    }
    rename_targets = set().union(*(set(group) for group in STOCK_ABI_RENAME_GROUPS))
    known = safe_source_replacements | rename_targets
    unknown = sorted(conflicts - known)
    fatal_unknown = sorted(reported_conflicts - known)
    if fatal_unknown:
        print(
            "unknown reported duplicate install target(s): " + ", ".join(fatal_unknown),
            file=sys.stderr,
        )
        return 11

    # Preserve each stock ABI unit under distinct installed sonames as soon as
    # one member collides. extract-files.py rewrites proprietary callers.
    renames: dict[str, str] = {}
    for group in STOCK_ABI_RENAME_GROUPS:
        if conflicts & set(group):
            renames.update(group)
    drops = safe_source_replacements
    changes: list[tuple[str, str, str]] = []
    output: list[str] = []

    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            output.append(line)
            continue
        parsed = parse_entry(line)
        if parsed is None:
            output.append(line)
            continue
        prefix, src, dst, extras = parsed
        newline = "\n" if line.endswith("\n") else ""
        if dst in drops or src in drops:
            changes.append(("drop-source-replacement", src, ""))
            continue
        destination = renames.get(dst) or renames.get(src)
        if destination:
            extras = re.sub(r";MODULE_SUFFIX=_vendor(?=;|\||$)", "", extras)
            extras = re.sub(r";MAKE_COPY_RULE_ONLY(?=;|\||$)", "", extras)
            output.append(f"{prefix}{src}:{destination}{extras}{newline}")
            changes.append(("rename-stock-abi", src, destination))
            continue
        output.append(line)

    required = len(drops) + len(renames)
    if len(changes) != required:
        print(
            f"policy matched {len(changes)} blob entries, expected {required}; refusing partial fix",
            file=sys.stderr,
        )
        return 12

    args.blob_list.write_text("".join(output))
    args.audit_log.parent.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now(timezone.utc).isoformat()
    with args.audit_log.open("a") as audit:
        for action, src, dst in changes:
            audit.write(f"{timestamp}\t{args.round}\t{action}\t{src}\t{dst}\n")
    resolved = drops | set(renames)
    print("resolved duplicate installs: " + ", ".join(sorted(resolved)), flush=True)
    if unknown:
        print(
            "deferred non-allowlisted overlaps: " + ", ".join(unknown),
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
