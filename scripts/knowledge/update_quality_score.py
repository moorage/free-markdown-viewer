#!/usr/bin/env python3
from __future__ import annotations

from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "QUALITY_SCORE.md"


def exists(rel: str) -> bool:
    return (ROOT / rel).exists()


def main() -> int:
    lines = [
        "# QUALITY_SCORE.md",
        "",
        f"Last updated: {date.today().isoformat()}",
        "",
        "## Current status",
        "",
        f"- control-plane docs: {'present' if exists('AGENTS.md') and exists('ARCHITECTURE.md') else 'partial'}",
        f"- shell wrappers: {'present' if exists('scripts/build') and exists('scripts/test-unit') else 'missing'}",
        f"- harness app shell: {'present' if exists('Swift Markdown Viewer/Swift Markdown Viewer/Harness') else 'missing'}",
        f"- unit tests: {'present' if exists('Swift Markdown Viewer/Swift Markdown ViewerTests') else 'missing'}",
        f"- UI tests: {'present' if exists('Swift Markdown Viewer/Swift Markdown ViewerUITests') else 'missing'}",
        f"- expected artifacts: {'present' if exists('Fixtures/expected') else 'missing'}",
        f"- repo map: {'present' if exists('docs/generated/repo-map.json') else 'missing'}",
        "",
        "## Immediate debt",
        "",
        "1. keep the universal harness shell and scripts green",
        "2. keep checkpoint expectations aligned with real outputs",
        "3. keep simulator coverage honest when platform components are missing",
    ]
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
