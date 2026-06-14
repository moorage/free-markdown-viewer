# App Store Metadata Draft

Use this file as the source for App Store Connect listing text and screenshot planning.

## App identity

- App name: `Quick Markdown Viewer`
- Subtitle: `Read docs, diagrams, tables`
- Primary category: `Productivity`
- Pricing: `Free`

## Promotional text

Read local Markdown folders, inspect JSON/JSONC/NDJSON, search docs, jump with outlines, render Mermaid, preview media, inspect CSV/TSV, and print.

## What's New

Use this for the `What's New` field on the next App Store version:

Quick Markdown Viewer 1.7 adds structured JSON-family reading and improves macOS file-opening workflows:

- Open JSON, JSONC, NDJSON, and JSONL files in a collapsible structured viewer
- View JSON-family fenced blocks inside Markdown with source/viewer controls
- Keep original source line numbers visible while expanding, collapsing, and reading pretty JSON rows
- Quick Look previews now support JSON-family files with bounded native previews
- `qmv /path/to/file` on macOS now cold-starts directly to the file's parent folder with that file selected
- App-level file opens now cover Markdown, Mermaid, JSON-family files, CSV/TSV tables, and folders

## Description

Quick Markdown Viewer is a local-first reader for Markdown folders, documentation packets, CSV/TSV tables, and media-rich notes on Mac, iPhone, and iPad.

Open a folder of files you already have, or open a public GitHub repository URL when you need to inspect remote docs. The app keeps reading fast and direct: no account, no subscription, no in-app purchase, and no tracking layer.

Features:

- Open local folders and browse Markdown, CSV, and TSV files in a file sidebar
- Open JSON, JSONC, NDJSON, and JSONL files with collapsible structured rows
- Read JSON-family fenced code blocks inside Markdown without switching apps
- Expand and collapse folders, filter large file trees, and use keyboard navigation on macOS
- Search the current document with Command-F or all open documents with Command-Shift-F
- Click search results in the sidebar to jump to matches highlighted in the document
- Read Markdown with native rendering for headings, lists, tables, code blocks, links, images, GIFs, and local video
- Render Mermaid diagrams natively, then zoom and pan diagram previews
- Detach Mermaid diagram previews into resizable macOS windows
- Open a document outline, jump to headings, and track the current section while reading
- Open CSV and TSV files as native tables with controls for wrapping and sizing
- Preview linked media without converting your Markdown files
- Print the current document or assemble a cancellable background Print All packet
- Preview Markdown from Finder with the macOS Quick Look extension
- Install the optional `qmv` command-line launcher on macOS and open supported files directly from Terminal
- Open public GitHub repository and repository tree URLs, including branch and tag paths
- Hide dependency and vendor folders with editable ignore patterns per window
- Navigate between files with back and forward history
- Adjust viewer font size for comfortable reading

Quick Markdown Viewer is designed to stay lightweight and direct:

- no account required
- no subscription
- no in-app purchase
- no tracking
- no web view renderer

## Keywords

Use this final keyword set:

`markdown,viewer,json,mermaid,docs,readme,csv,quicklook,search,qmv`

## Support and policy URLs

- Marketing URL: `https://www.matthewpaulmoore.com/apps/free-markdown-viewer`
- Support URL: `https://www.matthewpaulmoore.com/apps/free-markdown-viewer/support`
- Privacy Policy URL: `https://www.matthewpaulmoore.com/legal/privacy`
- Terms URL: `https://www.matthewpaulmoore.com/legal/terms`

The website slug stays on `free-markdown-viewer` because those pages are live today; only the visible app name is `Quick Markdown Viewer`.

## App Review notes

Primary draft source:

- `docs/release/app-review-notes.md`

## Screenshot Shot List

Capture the same nine feature shots on each platform so the listing feels consistent.

Repository-owned capture set:

1. `Fixtures/app-store/Open Markdown Folders.md` -> `open-markdown-folders`
2. `Fixtures/app-store/Outline Navigation.md` -> `outline-navigation`
3. `Fixtures/app-store/Full Text Search.md` -> `full-text-search`
4. `Fixtures/app-store/Mermaid Workflow.md` -> `mermaid-workflow`
5. `Fixtures/app-store/Structured JSON.json` -> `structured-json`
6. `Fixtures/app-store/Metrics.csv` -> `tables-csv`
7. `Fixtures/app-store/Media Preview.md` -> `media-preview`
8. `Fixtures/app-store/Code and Printing.md` -> `code-print-quicklook`
9. `Fixtures/app-store/Command Line Launcher.md` -> `command-line-launcher`

Repeatable capture command:

- `./scripts/capture-app-store-screenshots --platform all`

Generated artifacts:

- `artifacts/app-store-screenshots/iphone/*.png`
- `artifacts/app-store-screenshots/ipad/*.png`
- `artifacts/app-store-screenshots/macos/*.png`

## Screenshot Captions

Suggested sequence for every platform:

1. `Browse local Markdown folders`
2. `Jump through long docs with outlines`
3. `Search one file or every open document`
4. `Render Mermaid diagrams natively`
5. `Inspect JSON, JSONC, and JSONL`
6. `Inspect CSV and TSV tables`
7. `Preview linked images, GIFs, and video`
8. `Read code, Quick Look, and print`
9. `Open docs from Terminal with qmv`
