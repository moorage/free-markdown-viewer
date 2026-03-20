#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

REQUIRED_FILES = [
    ROOT / "README.md",
    ROOT / "AGENTS.md",
    ROOT / "ARCHITECTURE.md",
    ROOT / ".agents" / "PLANS.md",
    ROOT / ".agents" / "IMPLEMENT.md",
    ROOT / ".agents" / "DOCUMENTATION.md",
    ROOT / "docs" / "PLANS.md",
    ROOT / "docs" / "RELIABILITY.md",
    ROOT / "docs" / "SECURITY.md",
    ROOT / "docs" / "QUALITY_SCORE.md",
    ROOT / "docs" / "harness.md",
    ROOT / "docs" / "debug-contracts.md",
]


def main() -> int:
    for path in REQUIRED_FILES:
        if not path.exists():
            print(f"ERROR: missing required file: {path.relative_to(ROOT)}")
            return 1

    for rel_dir in ("docs/exec-plans/active", "docs/exec-plans/completed", "docs/generated"):
        (ROOT / rel_dir).mkdir(parents=True, exist_ok=True)

    result = subprocess.run([sys.executable, str(ROOT / "scripts" / "check_execplan.py")], cwd=ROOT, check=False)
    if result.returncode != 0:
        return result.returncode

    print("Docs verification passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
