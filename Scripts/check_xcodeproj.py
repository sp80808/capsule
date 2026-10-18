#!/usr/bin/env python3
"""Verify Capsule.xcodeproj lists every source file that is on disk.

The project file is maintained by hand (no file-system-synchronized groups),
so a new file that nobody registered silently never gets compiled. This check
compares the PBXBuildFile/PBXFileReference graph against the contents of the
Capsule/ directory.

Usage:
    python3 Scripts/check_xcodeproj.py

Exit code 0 = project and disk agree, 1 = something is missing or stale.
"""

from __future__ import annotations

import plistlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "Capsule.xcodeproj" / "project.pbxproj"
SOURCES_DIR = ROOT / "Capsule"

SOURCE_SUFFIXES = {".swift"}


def load_project() -> dict:
    text = PROJECT.read_text()
    # pbxproj is an old-style plist; plistlib only reads the XML form.
    if text.lstrip().startswith("<?xml"):
        return plistlib.loads(text.encode())
    return parse_oldstyle(text)


def parse_oldstyle(text: str) -> dict:
    """Minimal reader for the openstep-style pbxproj grammar."""
    token_re = re.compile(
        r"""\s*(?:
            (?P<linecomment>//[^\n]*)
          | (?P<comment>/\*.*?\*/)
          | (?P<string>"(?:[^"\\]|\\.)*")
          | (?P<bare>[A-Za-z0-9_.$/+-]+)
          | (?P<open>\{)
          | (?P<close>\})
          | (?P<assign>=)
          | (?P<semicolon>;)
          | (?P<lparen>\()
          | (?P<rparen>\))
          | (?P<comma>,)
        )""",
        re.VERBOSE | re.DOTALL,
    )

    tokens: list[tuple[str, str]] = []
    position = 0
    text = text.strip()
    while position < len(text):
        match = token_re.match(text, position)
        if not match:
            raise ValueError(f"cannot tokenise at offset {position}: {text[position:position+40]!r}")
        position = match.end()
        kind = match.lastgroup
        value = match.group(kind)
        if kind in {"comment", "linecomment", "comma"}:
            continue
        if kind == "string":
            value = value[1:-1]
        tokens.append((kind, value))

    index = 0

    def parse_value():
        nonlocal index
        kind, value = tokens[index]
        if kind == "open":
            index += 1
            obj: dict = {}
            while tokens[index][0] != "close":
                key = tokens[index][1]
                index += 1  # key
                assert tokens[index][0] == "assign", tokens[index]
                index += 1  # =
                obj[key] = parse_value()
                if tokens[index][0] == "semicolon":
                    index += 1
            index += 1  # }
            return obj
        if kind == "lparen":
            index += 1
            items: list = []
            while tokens[index][0] != "rparen":
                items.append(parse_value())
                if tokens[index][0] == "comma":
                    index += 1
            index += 1  # )
            return items
        index += 1
        return value

    return parse_value()


def main() -> int:
    project = load_project()
    objects = project["objects"]

    referenced: dict[str, str] = {}
    for object_id, obj in objects.items():
        if obj.get("isa") == "PBXFileReference":
            referenced[obj["path"]] = object_id

    compiled_paths: set[str] = set()
    for obj in objects.values():
        if obj.get("isa") != "PBXSourcesBuildPhase":
            continue
        for build_file_id in obj.get("files", []):
            build_file = objects.get(build_file_id)
            if not build_file:
                print(f"FAIL sources phase references unknown build file {build_file_id}")
                return 1
            file_ref = objects.get(build_file["fileRef"])
            if not file_ref:
                print(f"FAIL build file {build_file_id} references unknown file ref")
                return 1
            compiled_paths.add(file_ref["path"])

    on_disk = {
        path.name
        for path in SOURCES_DIR.rglob("*")
        if path.is_file() and path.suffix in SOURCE_SUFFIXES
    }

    failures: list[str] = []
    for name in sorted(on_disk - compiled_paths):
        failures.append(f"{name} is on disk but not in the Sources build phase")
    for name in sorted(compiled_paths - on_disk):
        failures.append(f"{name} is in the Sources build phase but missing from disk")

    for build_file_id, obj in objects.items():
        if obj.get("isa") != "PBXBuildFile":
            continue
        if obj["fileRef"] not in objects:
            failures.append(f"PBXBuildFile {build_file_id} has a dangling fileRef")

    ids = list(objects)
    if len(ids) != len(set(ids)):
        failures.append("duplicate object ids in project.pbxproj")

    if failures:
        for failure in failures:
            print(f"FAIL {failure}")
        return 1

    print(f"ok   {len(on_disk)} Swift files registered in Capsule.xcodeproj")
    print(f"ok   {len(referenced)} file references resolve")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
