# App Review Notes Draft

Use this as the starting point for the App Review Notes field in App Store Connect.

## Suggested notes

Quick Markdown Viewer is a free, local-first Markdown viewer for macOS, iPhone, and iPad.

- No account or sign-in is required.
- No in-app purchases are used.
- The app's primary function is to open a folder the user chooses and render Markdown files plus local media references inside that folder.
- Each opened window includes an explicit Ignore Patterns sheet opened from the eye button in the window chrome. The comma-separated patterns only filter that window's sidebar contents; they do not delete, move, upload, or modify files.
- New windows default to ignoring common dependency folders: `node_modules`, `venv`, `.venv`, and `vendor`.
- The app can also open a public GitHub repository URL or repository tree URL that the user explicitly pastes into the app; the app resolves the selected branch or tag, caches a local snapshot for offline reopen, and renders Markdown, CSV, and TSV files from that cached snapshot.
- The app can also render direct image and video URLs that the user authored inside Markdown files; this is limited to media fetching for the opened document content, not general web browsing, accounts, ads, or analytics.
- The app can print the currently selected file or the full opened workspace on macOS, iPhone, and iPad using the system print flow.
- On macOS, first launch automatically presents an `NSOpenPanel` titled `Open Folder`.
- The same folder-selection flow is also available on macOS through `File > Open Folder…` with `Command-O` and from the empty-state `Open Folder` button.
- The same empty state on macOS and iOS/iPadOS also accepts a pasted public GitHub repository URL and a `Load` action so reviewers can test the GitHub path without supplying local content first.
- On macOS, users can also choose `File > Install Command Line Tool…` or the empty-state `Install qmv` action to install a small `qmv` launcher at `~/.local/bin/qmv`; the app asks for one-time access to the user's home folder so it can create `~/.local/bin` if needed and write only that launcher there.
- The app uses `com.apple.security.files.user-selected.read-write` because the sandboxed macOS app must read the exact folder the reviewer selects and, when the user explicitly chooses `Install Command Line Tool…`, write only the `qmv` launcher into the user-approved location under `~/.local/bin`.
- The app also uses `com.apple.security.files.user-selected.executable` only so that user-approved `qmv` launcher can be written as a runnable shell tool. Apple documents this entitlement for sandboxed apps that create executable files such as shell scripts. In this app it is used only for the explicit `Install Command Line Tool…` flow and only for the one launcher file at `~/.local/bin/qmv`; the app does not install command-line tools silently, mark arbitrary files executable, or write outside explicit user approval.
- The macOS app uses `com.apple.security.network.client` only for user-initiated network fetches: direct media URLs authored inside Markdown and public GitHub repository snapshots that the user explicitly opens. The app does not include a web view, login flow, analytics SDK, or background network service.
- The app does not request blanket Downloads, Documents, or full-disk access.
- File access is user initiated through the macOS Open panel and the iPhone/iPad Files picker.
- The app does not require any external service credentials to review its primary functionality.

If App Review needs a quick test flow:

1. Launch the app.
2. On macOS, accept the `Open Folder` panel that appears automatically, or choose `File > Open Folder…`.
3. Pick any folder that contains Markdown files.
4. Optionally choose `File > Install Command Line Tool…`, approve access to the home folder when prompted, and run `qmv ..` from Terminal to reopen the app to a folder or `qmv /path/to/file.md` to reopen the file's containing folder with that file selected.
5. Use the eye button in the window chrome to open Ignore Patterns, edit the comma-separated list if desired, and choose Done.
6. Select a Markdown, CSV, or TSV file from the sidebar.
7. Verify that the document renders and that navigation plus printing work.

Optional GitHub test flow:

1. Launch the app and leave the empty state visible.
2. Paste `https://github.com/moorage/free-markdown-viewer/tree/main/Fixtures/app-store` into the GitHub URL field.
3. Choose `Load`.
4. Verify that the sidebar populates with Markdown files from that repository subtree and that the selected document renders.

Replace this draft if the shipped app behavior changes before submission.
