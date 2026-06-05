# App Review Notes Draft

Use this as the starting point for the App Review Notes field in App Store Connect. Keep it under Apple's 4000-character field limit.

## Suggested notes

Quick Markdown Viewer is a free, local-first Markdown viewer for macOS, iPhone, and iPad.

No account, sign-in, in-app purchase, analytics SDK, tracking, web view, background network service, or external credential is required.

Resolution for the previous macOS rejection: this build removes the app-managed App Store update checker, automatic update prompts, skip-version state, and macOS Check for Updates menu item.

Primary review flow:

1. Launch the app.
2. On macOS, accept the Open Folder panel or choose File > Open Folder. On iPhone/iPad, use the Files picker.
3. Pick a folder containing Markdown files, or paste `https://github.com/moorage/free-markdown-viewer/tree/main/Fixtures/app-store` into the GitHub URL field and choose Load.
4. Select Markdown, CSV, or TSV files from the sidebar.
5. Use Command-F or Command-Shift-F on macOS to open current-document or all-document search. Search results appear in the sidebar, are clickable, and highlight matches in the document.
6. On a Markdown document with headings, open the Outline panel, select a heading, and verify the reader scrolls there. The outline highlights the current section and is resizable on macOS/iPad.
7. Open a Markdown document containing a Mermaid fenced code block. The app renders it natively; on macOS the preview can be detached into a resizable window.
8. Verify CSV/TSV files render as native tables; standalone delimited files use a lazy table surface for large files.
9. Drag a supported local Markdown file onto the macOS app to open that file's parent folder in a new window with the dropped file selected.
10. In Finder on macOS, use Quick Look on a Markdown file. The bundled extension shows rendered Markdown by default, supports Source mode, renders inline Mermaid as a bounded native diagram preview, and shows local image attachments.
11. Use Print for the current document or Print All for the workspace. Print All prepares in the background, can be cancelled, and blocks completely empty output before opening the system print panel.
12. Optionally use the eye button to inspect Ignore Patterns. These only filter the sidebar and never delete, move, upload, or modify files.

Network use: public GitHub snapshots explicitly opened by the user and direct media URLs authored inside Markdown. The app does not check for updates itself, prompt users about updates, or run a background network service.

macOS sandbox entitlements: user-selected read-write is used for folders the reviewer chooses and for the explicit command-line tool install flow. user-selected executable is used only when the user chooses File > Install Command Line Tool or the empty-state Install qmv action; it writes one launcher at `~/.local/bin/qmv` after user-approved home-folder access. The app includes a Markdown Quick Look preview extension for Finder previews. The app does not silently install tools and does not request blanket Downloads, Documents, or full-disk access.
