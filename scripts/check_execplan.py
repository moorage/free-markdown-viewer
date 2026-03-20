#!/usr/bin/env python3
"""Validate active ExecPlans against the repository's plan schema."""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ACTIVE_DIR = ROOT / "docs" / "exec-plans" / "active"

REQUIRED_HEADINGS = [
    "Purpose / Big Picture",
    "Progress",
    "Surprises & Discoveries",
    "Decision Log",
    "Outcomes & Retrospective",
    "Context and Orientation",
    "Plan of Work",
    "Concrete Steps",
    "Validation and Acceptance",
    "Idempotence and Recovery",
    "Artifacts and Notes",
    "Interfaces and Dependencies",
]

TIMESTAMP_RE = re.compile(r"\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}Z")


def iter_plans(paths: list[Path]) -> list[Path]:
    if paths:
        return [path if path.is_absolute() else (ROOT / path) for path in paths]
    if not ACTIVE_DIR.exists():
        return []
    return sorted(path for path in ACTIVE_DIR.glob("*.md") if path.is_file())


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate active ExecPlans.")
    parser.add_argument("plans", nargs="*", type=Path)
    args = parser.parse_args()

    plans = iter_plans(args.plans)
    if not plans:
        print("OK: no active ExecPlans found.")
        return 0

    exit_code = 0
    for plan in plans:
        text = plan.read_text(encoding="utf-8")
        missing = [
            heading for heading in REQUIRED_HEADINGS
            if not re.search(rf"^##\s+{re.escape(heading)}\s*$", text, re.MULTILINE)
        ]
        rel = plan.relative_to(ROOT)
        if missing:
            print(f"ERROR: {rel} is missing required sections:")
            for heading in missing:
                print(f"  - {heading}")
            exit_code = 1
            continue
        if not TIMESTAMP_RE.search(text):
            print(f"ERROR: {rel} is missing timestamped progress entries.")
            exit_code = 1
            continue
        print(f"OK: {rel}")
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
