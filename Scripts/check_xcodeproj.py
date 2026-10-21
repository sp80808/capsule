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
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "Capsule.xcodeproj" / "project.pbxproj"
SOURCES_DIR = ROOT / "Capsule"

SOURCE_SUFFIXES = {".swift"}
SKIP_DIRS = {".git", ".build", "DerivedData", "build", ".venv"}


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


def check_schemes(objects: dict) -> list[str]:
    """Every blueprint a shared scheme points at must exist in the project."""
    problems: list[str] = []
    schemes = sorted(PROJECT.parent.glob("xcshareddata/xcschemes/*.xcscheme"))
    for scheme in schemes:
        try:
            root = ElementTree.fromstring(scheme.read_text())
        except ElementTree.ParseError as error:
            problems.append(f"{scheme.name} is not valid XML: {error}")
            continue

        found = 0
        for reference in root.iter("BuildableReference"):
            blueprint = reference.get("BlueprintIdentifier", "")
            found += 1
            if blueprint not in objects:
                problems.append(
                    f"{scheme.name} references unknown blueprint {blueprint} "
                    f"({reference.get('BuildableName')})"
                )
        if found == 0:
            problems.append(f"{scheme.name} does not reference any target")
    return problems


def main() -> int:
    project = load_project()
    objects = project["objects"]

    failures: list[str] = []
    failures.extend(check_schemes(objects))

    # ---- every Swift file on disk is compiled, and vice versa -------------
    on_disk = {
        path.name
        for path in ROOT.rglob("*.swift")
        if path.is_file() and not SKIP_DIRS.intersection(path.parts)
    }

    compiled: set[str] = set()
    for build_file_id, obj in objects.items():
        if obj.get("isa") != "PBXBuildFile":
            continue
        file_ref = objects.get(obj["fileRef"])
        if file_ref is None:
            failures.append(f"PBXBuildFile {build_file_id} has a dangling fileRef")
            continue
        # Only source-phase build files matter for the disk comparison.
        compiled.add(file_ref["path"])

    source_phase_files: set[str] = set()
    for obj in objects.values():
        if obj.get("isa") != "PBXSourcesBuildPhase":
            continue
        for build_file_id in obj.get("files", []):
            file_ref = objects.get(objects.get(build_file_id, {}).get("fileRef", ""))
            if file_ref is None:
                failures.append(f"sources phase references unknown build file {build_file_id}")
                continue
            source_phase_files.add(file_ref["path"])

    swift_on_disk = {
        name
        for name in on_disk
        if name.endswith(".swift")
    }
    for name in sorted(swift_on_disk - source_phase_files):
        failures.append(f"{name} is on disk but not in any Sources build phase")
    for name in sorted(source_phase_files - on_disk):
        failures.append(f"{name} is in a Sources build phase but missing from disk")

    # ---- structural integrity -------------------------------------------
    referenced_config_lists: set[str] = set()

    for object_id, obj in objects.items():
        isa = obj.get("isa")

        if isa == "PBXNativeTarget":
            config_list = obj.get("buildConfigurationList")
            if config_list not in objects:
                failures.append(f"target {obj.get('name')} has no build configuration list")
            else:
                referenced_config_lists.add(config_list)

            for phase_id in obj.get("buildPhases", []):
                if phase_id not in objects:
                    failures.append(f"target {obj.get('name')} references missing build phase {phase_id}")

            product = obj.get("productReference")
            if product and product not in objects:
                failures.append(f"target {obj.get('name')} references missing product {product}")

            for dependency_id in obj.get("dependencies", []):
                dependency = objects.get(dependency_id)
                if dependency is None:
                    failures.append(f"target {obj.get('name')} has a dangling dependency")
                    continue
                if dependency.get("target") not in objects:
                    failures.append(f"dependency {dependency_id} points at a missing target")
                if dependency.get("targetProxy") not in objects:
                    failures.append(f"dependency {dependency_id} points at a missing target proxy")

        elif isa == "PBXContainerItemProxy":
            if obj.get("containerPortal") not in objects:
                failures.append(f"proxy {object_id} points at a missing container portal")
            if obj.get("remoteGlobalIDString") not in objects:
                failures.append(f"proxy {object_id} points at a missing remote target")

        elif isa == "XCConfigurationList":
            configs = obj.get("buildConfigurations", [])
            if not configs:
                failures.append(f"configuration list {object_id} has no configurations")
            for config_id in configs:
                if config_id not in objects:
                    failures.append(f"configuration list {object_id} references missing config {config_id}")

    project_object = objects.get(project.get("rootObject", ""), {})
    referenced_config_lists.add(project_object.get("buildConfigurationList", ""))
    for object_id, obj in objects.items():
        if obj.get("isa") == "XCConfigurationList" and object_id not in referenced_config_lists:
            failures.append(f"configuration list {object_id} is not used by any target or the project")

    targets = [o for o in objects.values() if o.get("isa") == "PBXNativeTarget"]
    test_targets = [t for t in targets if t.get("productType") == "com.apple.product-type.bundle.unit-test"]
    for test_target in test_targets:
        names = {t.get("name") for t in targets}
        settings = _release_settings(objects, test_target)
        if "TEST_HOST" not in settings or "BUNDLE_LOADER" not in settings:
            failures.append(f"test target {test_target.get('name')} is not hosted by the app")

    if len(objects) != len(set(objects)):
        failures.append("duplicate object ids in project.pbxproj")

    for failure in failures:
        print(f"FAIL {failure}")

    if failures:
        return 1

    print(f"ok   {len(swift_on_disk)} Swift files on disk, all registered")
    print(f"ok   {len(targets)} target(s): {', '.join(sorted(t['name'] for t in targets))}")
    print(f"ok   {len(test_targets)} test target(s) hosted by the app")
    print(f"ok   {len(list(PROJECT.parent.glob('xcshareddata/xcschemes/*.xcscheme')))} shared scheme(s) resolve")
    return 0


def _release_settings(objects: dict, target: dict) -> dict:
    config_list = objects.get(target.get("buildConfigurationList"), {})
    for config_id in config_list.get("buildConfigurations", []):
        settings = objects.get(config_id, {}).get("buildSettings", {})
        if settings:
            return settings
    return {}


if __name__ == "__main__":
    raise SystemExit(main())
