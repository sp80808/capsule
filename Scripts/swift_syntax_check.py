#!/usr/bin/env python3
"""Syntax-check every Swift file in the repository with tree-sitter.

This is *not* a type checker and it is not a substitute for `xcodebuild` on a
Mac (nothing on Linux can resolve AppKit/SwiftUI). What it does catch is every
syntax error, unbalanced brace, stray token and malformed declaration, which is
the class of mistake that is easy to make when editing Swift without a
compiler in the loop.

Usage:
    python3 Scripts/swift_syntax_check.py [paths ...]

Exit code 0 = all files parsed cleanly, 1 = at least one syntax error.

Requires:  pip install tree-sitter tree-sitter-swift
"""

from __future__ import annotations

import sys
from pathlib import Path

try:
    from tree_sitter import Language, Parser
    import tree_sitter_swift
except ImportError:  # pragma: no cover - dependency hint
    sys.stderr.write(
        "missing dependency: pip install tree-sitter tree-sitter-swift\n"
    )
    raise SystemExit(2)

SKIP_DIRS = {".git", ".build", "DerivedData", "build", ".venv"}


def swift_files(paths: list[Path]) -> list[Path]:
    files: list[Path] = []
    for path in paths:
        if path.is_file():
            files.append(path)
            continue
        for candidate in sorted(path.rglob("*.swift")):
            if SKIP_DIRS.intersection(candidate.parts):
                continue
            files.append(candidate)
    return files


def problems(parser: Parser, source: bytes) -> list[tuple[int, int, str]]:
    """Return (line, column, message) for every ERROR/MISSING node."""
    tree = parser.parse(source)
    found: list[tuple[int, int, str]] = []

    def walk(node) -> None:
        if node.is_missing:
            found.append(
                (
                    node.start_point[0] + 1,
                    node.start_point[1] + 1,
                    f"MISSING {node.type}",
                )
            )
        elif node.type == "ERROR":
            snippet = source[node.start_byte : node.end_byte][:60].decode(
                "utf-8", "replace"
            )
            found.append(
                (
                    node.start_point[0] + 1,
                    node.start_point[1] + 1,
                    f"ERROR near {snippet!r}",
                )
            )
        for child in node.children:
            walk(child)

    walk(tree.root_node)
    return found


def main(argv: list[str]) -> int:
    root = Path(__file__).resolve().parent.parent
    targets = [Path(a) for a in argv] or [root]
    files = swift_files(targets)
    if not files:
        print("no Swift files found")
        return 1

    parser = Parser(Language(tree_sitter_swift.language()))
    failures = 0
    for file in files:
        issues = problems(parser, file.read_bytes())
        if issues:
            failures += 1
            print(f"FAIL {file}")
            for line, column, message in issues[:10]:
                print(f"     {line}:{column} {message}")
        else:
            print(f"ok   {file}")
    print(f"\n{len(files) - failures}/{len(files)} files parsed cleanly")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
