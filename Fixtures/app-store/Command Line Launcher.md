# Command Line Launcher

Install `qmv` on macOS to open docs from Terminal without hunting through Finder.

```bash
qmv docs/exec-plans/active/2026-06-14-structured-json-viewer.md
```

The app opens one viewer window at the file's parent folder and selects the file you named.

Supported launch targets:

- Markdown and Mermaid files
- JSON, JSONC, NDJSON, and JSONL files
- CSV and TSV tables
- Whole folders of readable documents

The launcher is optional, installed only from the app, and writes one script to `~/.local/bin/qmv` after user approval.
