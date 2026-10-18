#!/usr/bin/env python3
"""Cross-reference member accesses against the types declared in this repo.

There is no Swift toolchain on Linux, so `xcodebuild` cannot run here. This is
the next best thing: it parses every file with tree-sitter, builds a map of
"which members does each Capsule type declare", works out the type of the
receivers it can (`manager`, `store`, `self`, `AudioDeviceService`, …) and
reports any member access it cannot find.

That catches the mistakes that a syntax check cannot: a renamed method, a
property that was never added, a typo in a call site.

Not a type checker. Unknown receivers are skipped, and stdlib/framework members
on foreign types are out of scope.

Usage:
    python3 Scripts/swift_cross_reference.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

try:
    from tree_sitter import Language, Parser
    import tree_sitter_swift
except ImportError:  # pragma: no cover
    sys.stderr.write("missing dependency: pip install tree-sitter tree-sitter-swift\n")
    raise SystemExit(2)

ROOT = Path(__file__).resolve().parent.parent
SKIP_DIRS = {".git", ".build", "DerivedData", "build", ".venv"}

DECL_TYPES = {
    "class_declaration",
    "struct_declaration",
    "enum_declaration",
    "protocol_declaration",
    "extension_declaration",
}
MEMBER_NODES = {
    "property_declaration",
    "computed_property",
    "function_declaration",
    "init_declaration",
    "deinit_declaration",
    "protocol_function_declaration",
    "subscript_declaration",
    "enum_entry",
}
# Members provided by the standard protocols our types conform to.
INHERITED = {
    "id",
    "body",
    "hashValue",
    "objectWillChange",
    "description",
    "debugDescription",
    "rawValue",
    "count",
    "self",
    "none",
    "some",
    "ID",
    "Element",
}

# Members provided by Array/Set/Dictionary — variables declared as a collection
# of one of our types are checked against these instead.
COLLECTION_MEMBERS = {
    "append", "appendContentsOf", "allSatisfy", "capacity", "compactMap", "contains",
    "count", "dropFirst", "dropLast", "elementsEqual", "enumerated", "filter", "first",
    "firstIndex", "flatMap", "forEach", "indices", "insert", "isEmpty", "joined",
    "keys", "last", "map", "max", "min", "prefix", "reduce", "remove", "removeAll",
    "removeFirst", "removeLast", "removeValue", "reversed", "reserveCapacity",
    "sorted", "sort", "split", "startIndex", "endIndex", "subtracting", "union",
    "values", "withIndex", "zip",
}

MEMBER_ACCESS = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\??\s*\.\s*([A-Za-z_][A-Za-z0-9_]*)")
# `Type.shared.member` — every singleton in the app is called `shared`, so the
# bare name is ambiguous; the enclosing type is what identifies it.
SINGLETON_ACCESS = re.compile(
    r"\b([A-Z][A-Za-z0-9_]*)\.shared\s*\.\s*([A-Za-z_][A-Za-z0-9_]*)"
)


class Module:
    def __init__(self) -> None:
        self.members: dict[str, set[str]] = {}
        self.var_types: dict[str, str] = {}
        self.file_types: dict[str, set[str]] = {}

    def add_member(self, type_name: str, member: str) -> None:
        self.members.setdefault(type_name, set()).add(member)

    def resolve(self, receiver: str) -> str | None:
        if receiver in self.members:
            return receiver
        return self.var_types.get(receiver)


def text(node, source: bytes) -> str:
    return source[node.start_byte : node.end_byte].decode("utf-8", "replace")


def first_child(node, *types: str):
    for child in node.children:
        if child.type in types:
            return child
    return None


def declared_name(node, source: bytes) -> str | None:
    """Name of a property/computed property declaration."""
    if node.type == "computed_property":
        identifier = first_child(node, "simple_identifier", "pattern")
        if identifier is not None and identifier.type == "pattern":
            inner = first_child(identifier, "simple_identifier")
            return text(inner, source) if inner else None
        return text(identifier, source) if identifier is not None else None

    pattern = first_child(node, "pattern")
    if pattern is not None:
        identifier = first_child(pattern, "simple_identifier")
        if identifier is not None:
            return text(identifier, source)
    identifier = first_child(node, "simple_identifier")
    return text(identifier, source) if identifier is not None else None


def declared_type(node, source: bytes) -> str | None:
    """Type annotation of a property or parameter, if it has one."""
    annotation = first_child(node, "type_annotation")
    if annotation is None:
        return None
    for candidate in annotation.children:
        if candidate.type == "user_type":
            inner = first_child(candidate, "type_identifier")
            return text(inner, source) if inner else None
        if candidate.type == "optional_type":
            inner = first_child(candidate, "user_type")
            if inner is not None:
                ident = first_child(inner, "type_identifier")
                return text(ident, source) if ident else None
        if candidate.type == "array_type":
            return "Array"
    return None


def inferred_type(node, source: bytes) -> str | None:
    """`static let shared = MixerPresenter()` → MixerPresenter."""
    call = first_child(node, "call_expression")
    if call is None:
        return None
    identifier = first_child(call, "simple_identifier")
    return text(identifier, source) if identifier is not None else None


def member_accesses(code: str):
    """Yield (receiver, member, offset) for every `a.b`, including chains.

    `finditer` would consume the member of one access and miss it acting as the
    receiver of the next (`self?.manager?.focus()`), so restart each search at
    the member instead of after it.
    """
    position = 0
    while True:
        match = MEMBER_ACCESS.search(code, position)
        if match is None:
            return
        yield match.group(1), match.group(2), match.start()
        position = match.start(2)


def strip_noise(source: bytes) -> str:
    """Blank out comments and string literals so member regex only sees code."""
    code = source.decode("utf-8", "replace")
    code = re.sub(r'"""(?:.|\n)*?"""', '""', code)
    code = re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', code)
    code = re.sub(r"//[^\n]*", "", code)
    code = re.sub(r"/\*(?:.|\n)*?\*/", "", code)
    return code


def build(parser: Parser, files: list[Path]) -> tuple[Module, dict[Path, str]]:
    module = Module()
    sources: dict[Path, str] = {}

    for file in files:
        raw = file.read_bytes()
        sources[file] = strip_noise(raw)
        tree = parser.parse(raw)
        local_types: set[str] = set()

        def visit(node, enclosing: str | None) -> None:
            if node.type in DECL_TYPES:
                identifier = first_child(node, "type_identifier")
                name = text(identifier, raw) if identifier is not None else None
                if name:
                    local_types.add(name)
                    module.members.setdefault(name, set())
                    if enclosing:
                        module.add_member(enclosing, name)
                    enclosing = name
            elif enclosing is not None and node.type in MEMBER_NODES:
                name = declared_name(node, raw)
                if name:
                    module.add_member(enclosing, name)
                if node.type == "init_declaration":
                    module.add_member(enclosing, "init")

            # Record variable → type mappings anywhere in the file.
            if node.type == "property_declaration":
                name = declared_name(node, raw)
                var_type = declared_type(node, raw) or inferred_type(node, raw)
                if name and name != "shared" and var_type in module.members:
                    module.var_types.setdefault(name, var_type)
            elif node.type == "parameter":
                identifiers = [c for c in node.children if c.type == "simple_identifier"]
                var_type = declared_type(node, raw)
                if identifiers and var_type:
                    module.var_types.setdefault(text(identifiers[-1], raw), var_type)

            for child in node.children:
                visit(child, enclosing)

        visit(tree.root_node, None)
        module.file_types[file] = local_types

    return module, sources


def main() -> int:
    files = [
        path
        for path in sorted((ROOT / "Capsule").rglob("*.swift"))
        if not SKIP_DIRS.intersection(path.parts)
    ]
    parser = Parser(Language(tree_sitter_swift.language()))
    module, sources = build(parser, files)
    module.members["Array"] = set(COLLECTION_MEMBERS)

    print(f"types: {len(module.members)}  members: {sum(len(m) for m in module.members.values())}")

    problems: list[str] = []
    for file, code in sources.items():
        local_union: set[str] = set()
        for type_name in module.file_types.get(file, set()):
            local_union |= module.members.get(type_name, set())

        for match in SINGLETON_ACCESS.finditer(code):
            type_name, member = match.group(1), match.group(2)
            if type_name not in module.members:
                continue
            if member in module.members[type_name] or member in INHERITED:
                continue
            line = code[: match.start()].count("\n") + 1
            problems.append(f"{file}:{line} {type_name}.shared.{member} — '{member}' is not a member of {type_name}")

        for receiver, member, offset in member_accesses(code):
            if receiver == "shared":
                continue
            if receiver == "self":
                pool = local_union | INHERITED
                if pool and member not in pool:
                    line = code[:offset].count("\n") + 1
                    problems.append(f"{file}:{line} self.{member} is not declared in this file's types")
                continue

            type_name = module.resolve(receiver)
            if type_name is None:
                continue
            if member in module.members.get(type_name, set()) or member in INHERITED:
                continue
            line = code[:offset].count("\n") + 1
            problems.append(
                f"{file}:{line} {receiver}.{member} — '{member}' is not a member of {type_name}"
            )

    for problem in problems:
        print("FAIL", problem)

    if problems:
        print(f"\n{len(problems)} unresolved member access(es)")
        return 1
    print("ok   every resolvable member access matches a declared member")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
