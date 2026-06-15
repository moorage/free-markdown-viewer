# App Review Notes Draft

Use this as the starting point for the App Review Notes field in App Store Connect. Keep it under Apple's 4000-character field limit.

## Suggested notes

Quick Markdown Viewer is a free, local-first Markdown viewer for macOS, iPhone, and iPad.

No account, sign-in, in-app purchase, analytics SDK, tracking, web view, background network service, or external credential is required.

This build adds structured JSON-family viewing, corrected macOS `qmv /path/to/file` cold-start behavior, full nested file paths in the viewer header, and sticky ancestor folders in the file sidebar. It still does not include app-managed update checks, automatic update prompts, skip-version state, or a macOS Check for Updates menu item.

Primary review flow:

1. Launch the app.
2. On macOS, accept the Open Folder panel or choose File > Open Folder. On iPhone/iPad, use the Files picker.
3. Pick a folder containing Markdown files, or paste `https://github.com/moorage/free-markdown-viewer/tree/main/Fixtures/app-store` into the GitHub URL field and choose Load.
4. Select Markdown, JSON, JSONC, NDJSON, JSONL, CSV, or TSV files from the sidebar. Nested files show their full folder path in the header; the sidebar keeps the selected file's ancestor folders visible above the scrolling file list.
5. Use Command-F or Command-Shift-F on macOS to open current-document or all-document search. Search results appear in the sidebar, are clickable, and highlight matches in the document.
6. On a Markdown document with headings, open the Outline panel, select a heading, and verify the reader scrolls there. The outline highlights the current section and is resizable on macOS/iPad.
7. Open a Markdown document containing a Mermaid fenced code block. The app renders it natively; on macOS the preview can be detached into a resizable window.
8. Verify JSON-family files render in the structured viewer with Viewer/Source controls, collapsible rows, source line gutters, and syntax highlighting.
9. Verify CSV/TSV files render as native tables; standalone delimited files use a lazy table surface for large files.
10. Drag a supported local Markdown, JSON-family, Mermaid, CSV, or TSV file onto the macOS app to open that file's parent folder in a new window with the dropped file selected.
11. On macOS, install `qmv` if desired and run `qmv /path/to/supported-file.md` or `qmv /path/to/supported-file.json`; the app should open one viewer window at the parent folder with that file selected, without an extra Open Folder dialog.
12. In Finder on macOS, use Quick Look on a Markdown or JSON-family file. The bundled extension shows rendered Markdown by default, supports Source mode, renders inline Mermaid as a bounded native diagram preview, shows local image attachments, and previews JSON-family files with native line-numbered output.
13. Use Print for the current document or Print All for the workspace. Print All prepares in the background, can be cancelled, and blocks completely empty output before opening the system print panel.
14. Optionally use the eye button to inspect Ignore Patterns. These only filter the sidebar and never delete, move, upload, or modify files.

Network use: public GitHub snapshots explicitly opened by the user and direct media URLs authored inside Markdown. The app does not check for updates itself, prompt users about updates, or run a background network service.

macOS sandbox entitlements: user-selected read-write is used for folders the reviewer chooses and for the explicit command-line tool install flow. user-selected executable is used only when the user chooses File > Install Command Line Tool or the empty-state Install qmv action; it writes one launcher at `~/.local/bin/qmv` after user-approved home-folder access. The app includes a Markdown Quick Look preview extension for Finder previews. The app does not silently install tools and does not request blanket Downloads, Documents, or full-disk access.
