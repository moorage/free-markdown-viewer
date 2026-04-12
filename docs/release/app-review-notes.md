# App Review Notes Draft

Use this as the starting point for the App Review Notes field in App Store Connect.

## Suggested notes

Quick Markdown Viewer is a free, local-first Markdown viewer for macOS, iPhone, and iPad.

- No account or sign-in is required.
- No in-app purchases are used.
- The app's primary function is to open a folder the user chooses and render Markdown files plus local media references inside that folder.
- On macOS, first launch automatically presents an `NSOpenPanel` titled `Open Folder`.
- The same folder-selection flow is also available on macOS through `File > Open Folder…` with `Command-O` and from the empty-state `Open Folder` button.
- The app uses `com.apple.security.files.user-selected.read-only` because the sandboxed macOS app must read the exact folder the reviewer selects and the Markdown and media files inside it.
- The app does not request blanket Downloads, Documents, or full-disk access.
- File access is user initiated through the macOS Open panel and the iPhone/iPad Files picker.
- The app does not require any external service credentials to review its primary functionality.

If App Review needs a quick test flow:

1. Launch the app.
2. On macOS, accept the `Open Folder` panel that appears automatically, or choose `File > Open Folder…`.
3. Pick any folder that contains Markdown files.
4. Select a Markdown file from the sidebar.
5. Verify that the document renders and that navigation works.

Replace this draft if the shipped app behavior changes before submission.
