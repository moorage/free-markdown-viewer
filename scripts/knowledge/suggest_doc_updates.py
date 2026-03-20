#!/usr/bin/env python3
from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

PATH_HINTS = {
    "scripts/": ["docs/harness.md", "AGENTS.md"],
    "docs/": ["docs/PLANS.md", "docs/QUALITY_SCORE.md"],
    "Swift Markdown Viewer/Swift Markdown Viewer/": ["ARCHITECTURE.md", "docs/debug-contracts.md"],
    "Swift Markdown Viewer/Swift Markdown ViewerUITests/": ["docs/harness.md", "docs/debug-contracts.md"],
    "Fixtures/": ["docs/harness.md", "docs/debug-contracts.md"],
}


def main() -> int:
    result = subprocess.run(["git", "status", "--porcelain"], cwd=ROOT, capture_output=True, text=True, check=False)
    changed = [line[3:] for line in result.stdout.splitlines() if len(line) > 3]
    suggestions = set()
    for path in changed:
        for prefix, docs in PATH_HINTS.items():
            if path.startswith(prefix):
                suggestions.update(docs)
    if not suggestions:
        print("No obvious doc updates suggested.")
        return 0
    print("Suggested doc updates:")
    for suggestion in sorted(suggestions):
        print(f"- {suggestion}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
