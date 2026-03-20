#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "generated" / "repo-map.json"

NAME_IGNORE = {
    ".git",
    ".DS_Store",
    "__pycache__",
    "node_modules",
    "DerivedData",
    "artifacts",
}

PATH_PREFIX_IGNORE = {
    "tmp",
    "Swift Markdown Viewer/Swift Markdown Viewer.xcodeproj/project.xcworkspace/xcuserdata",
    "Swift Markdown Viewer/Swift Markdown Viewer.xcodeproj/xcuserdata",
}


def should_ignore(path: Path) -> bool:
    rel = path.relative_to(ROOT)
    if path.name in NAME_IGNORE:
        return True
    rel_str = rel.as_posix()
    return any(rel_str == prefix or rel_str.startswith(f"{prefix}/") for prefix in PATH_PREFIX_IGNORE)


def walk(path: Path):
    items = []
    for child in sorted(path.iterdir(), key=lambda candidate: candidate.name):
        if should_ignore(child):
            continue
        if child.is_dir():
            items.append({"type": "dir", "name": child.name, "children": walk(child)})
        else:
            items.append({"type": "file", "name": child.name})
    return items


def main() -> int:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"root": ROOT.name, "tree": walk(ROOT)}, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
