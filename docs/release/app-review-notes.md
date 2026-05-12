# App Review Notes Draft

Use this as the starting point for the App Review Notes field in App Store Connect. Keep it under Apple's 4000-character field limit.

## Suggested notes

Quick Markdown Viewer is a free, local-first Markdown viewer for macOS, iPhone, and iPad.

No account, sign-in, in-app purchase, analytics SDK, tracking, web view, background network service, or external credential is required.

Primary review flow:

1. Launch the app.
2. On macOS, accept the Open Folder panel or choose File > Open Folder. On iPhone/iPad, use the Files picker.
3. Pick a folder containing Markdown files, or paste `https://github.com/moorage/free-markdown-viewer/tree/main/Fixtures/app-store` into the GitHub URL field and choose Load.
4. Select Markdown, CSV, or TSV files from the sidebar.
5. On a Markdown document with headings, open the Outline panel, select a heading, and verify the reader scrolls there. The outline highlights the current section and is resizable on macOS/iPad.
6. Verify CSV/TSV files render as native tables; standalone delimited files use a lazy table surface for large files.
7. Optionally use the eye button to inspect Ignore Patterns. These only filter the sidebar and never delete, move, upload, or modify files.

Network use: public GitHub snapshots explicitly opened by the user, direct media URLs authored inside Markdown, and Apple's App Store lookup endpoint for update checks. Update prompts can be skipped once or until the next released version; on macOS the manual action is Quick Markdown Viewer > Check for Updates.

macOS sandbox entitlements: user-selected read-write is used for folders the reviewer chooses and for the explicit command-line tool install flow. user-selected executable is used only when the user chooses File > Install Command Line Tool or the empty-state Install qmv action; it writes one launcher at `~/.local/bin/qmv` after user-approved home-folder access. The app does not silently install tools and does not request blanket Downloads, Documents, or full-disk access.
