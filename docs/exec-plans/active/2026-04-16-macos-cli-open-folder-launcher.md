# macOS CLI Launcher for Opening Workspaces

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

Add a macOS command-line entry point so `qmv ..` opens Quick Markdown Viewer to the parent directory from Terminal. The App Store build should not attempt a silent PATH mutation or background installer: current Apple sandbox guidance requires user approval before writing a runnable shell tool, and the app cannot rely on auto-installing a globally runnable CLI during App Store installation. Instead, the macOS app should support an explicit in-app `Install Command Line Tool…` flow that always writes `qmv` to `~/.local/bin/qmv`, requests one-time access to the user's home folder when needed, wires the installed launcher to open folders through Launch Services, and exposes a matching empty-state call to action when the launcher is not installed.

## Progress

- [x] (2026-04-16T07:12Z) Audited the existing macOS command/menu plumbing, empty-state UI, session restore flow, and workspace-opening code paths to identify the concrete implementation surfaces.
- [x] (2026-04-16T07:12Z) Confirmed the Xcode project currently ships only the app, unit-test, and UI-test targets, so a thin launcher script is a smaller and safer fit than introducing a second executable target for the first CLI version.
- [x] (2026-04-16T07:12Z) Confirmed from Apple sandbox documentation that App Store auto-install is not a viable default: writing a command-line shell script requires a user-selected destination and the `com.apple.security.files.user-selected.executable` entitlement, while user-selected file access does not permit the app to treat arbitrary PATH locations as writable install targets.
- [x] (2026-04-16T07:12Z) Drafted the implementation plan, validation path, and control-plane bookkeeping for the macOS CLI launcher workstream.
- [x] (2026-04-16T07:26Z) Added a macOS app-delegate intake path for external folder-open events, routed CLI-triggered opens into either the current empty window or a new window-scoped session, and preserved the existing multiwindow workspace behavior.
- [x] (2026-04-16T07:26Z) Added a macOS command-line tool installer that generates the `qmv` launcher, persists the chosen install path, detects stale or missing installs, and exposes `Install Command Line Tool…` in the macOS command menu plus an empty-state `Install \`qmv\`` affordance.
- [x] (2026-04-16T07:26Z) Added the macOS entitlements file for executable export, updated App Review notes for the new launcher flow, and extended unit/UI coverage around launcher generation and the empty-state installer prompt.
- [x] (2026-04-16T07:26Z) Revalidated the repo with `./scripts/test-unit`, `./scripts/test-ui-macos --smoke`, and the required ExecPlan/docs validation commands.
- [x] (2026-04-16T21:10Z) Reworked the installer to always target `~/.local/bin/qmv`, added one-time home-folder access guidance plus a persisted security-scoped bookmark for reinstall/remove, and updated the empty-state/app-review copy to match the fixed-path model.
- [x] (2026-04-16T21:18Z) Replaced the giant post-install Terminal snippet with a bundled `qmv-finish-terminal-setup.sh` resource and a short copyable `/bin/sh ...` command that points into the installed app bundle.
- [x] (2026-04-16T21:30Z) Fixed the final sandbox write failure by switching the macOS app entitlement from user-selected read-only to user-selected read-write while keeping the `qmv` write scope limited to explicit user-approved install flow.
- [x] (2026-04-16T21:42Z) Added a macOS-specific `Info.plist` with `CFBundleDocumentTypes` for `public.folder`, so Launch Services now delivers folder arguments from `qmv .` into the app instead of launching an empty window.

## Surprises & Discoveries

- Observation: the app already has a macOS-focused command surface that can host a CLI installer without a scene-architecture rewrite.
  Evidence: `Quick Markdown Viewer/Quick Markdown Viewer/Quick_Markdown_ViewerApp.swift` already installs `WindowOpenFolderCommands()`, and `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/WindowSceneRootView.swift` already publishes focused scene actions for `Open Folder…`.

- Observation: the empty-window experience already has a centered call to action and stable accessibility hooks, so the requested "install CLI" affordance can be added as a sibling action instead of inventing a new screen.
  Evidence: `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift` renders the no-workspace card through `emptyStateCard(...)`, and `Quick Markdown Viewer/Quick Markdown Viewer/Harness/AccessibilityIDs.swift` already exposes empty-state identifiers.

- Observation: the current app target does not use a checked-in entitlements plist, and the existing macOS sandbox surface is configured from Xcode build settings.
  Evidence: `docs/exec-plans/active/2026-04-10-macos-downloads-entitlement-removal.md` records that the signed app currently derives entitlements from target settings rather than from a repository-owned `.entitlements` file.

- Observation: the current codebase has no separate helper or CLI target to reuse.
  Evidence: `Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj/project.pbxproj` currently declares only the `Quick Markdown Viewer`, `Quick Markdown ViewerTests`, and `Quick Markdown ViewerUITests` native targets.

- Observation: Apple’s macOS sandbox guidance is compatible with exporting a launcher script to a user-chosen destination, but not with silently installing a PATH tool at App Store install time.
  Evidence: Apple’s `Accessing files from the macOS App Sandbox` and `Enabling App Sandbox` documentation state that writing executable shell tools in user-selected locations requires `com.apple.security.files.user-selected.executable`, and that user-selected file access does not let a sandboxed app treat arbitrary external install locations as freely writable defaults.

- Observation: a fixed `~/.local/bin/qmv` destination still needs an explicit user-approved access token in the sandbox; simply computing that path and writing there fails with a permission error in the real app.
  Evidence: local manual validation previously failed with “You don’t have permission to save the file `qmv` in the folder `bin`” until the flow was reworked around a one-time home-folder approval plus a persisted security-scoped bookmark.

- Observation: even with the correct real home path and a security-scoped bookmark, `com.apple.security.files.user-selected.read-only` still prevents writing the launcher into the approved destination.
  Evidence: the live app now fails at `/Users/matthewmoore/.local/bin/qmv` with “You don’t have permission to save the file `qmv` in the folder `bin`” until the entitlement is upgraded to user-selected read-write.

- Observation: the original post-installation UX produced a large inline shell snippet that was correct but clumsy to copy and visually noisy in the sheet.
  Evidence: `MacCommandLineToolManager.postInstallShellCommand(...)` previously generated the full PATH-fix script body inline and `CommandLineToolPostInstallSheet` rendered that entire body directly in the command panel.

- Observation: `open -b com.souschefstudio.Free-Markdown-Viewer <folder>` does not hand the folder to the app unless the bundle advertises folder-open support through Launch Services metadata.
  Evidence: the rebuilt app initially had no `CFBundleDocumentTypes` in its generated `Info.plist`, and `qmv .` launched the app into the blank state until the macOS bundle was updated to declare `public.folder`.

- Observation: macOS file-open delivery can be integrated without introducing a new document-based app architecture.
  Evidence: `Quick Markdown Viewer/Quick Markdown Viewer/Quick_Markdown_ViewerApp.swift` now uses an `NSApplicationDelegateAdaptor` to capture `openFiles` / `open urls` events and route them through a lightweight `ExternalWorkspaceOpenCoordinator`.

## Decision Log

- Decision: do not plan for automatic CLI installation on first launch or during App Store install.
  Rationale: the sandbox/App Store constraints make silent installation into a runnable PATH location both unreliable and review-hostile; the explicit installer flow is the smallest approach that matches platform rules.

- Decision: use a generated `qmv` launcher script for v1 rather than a second bundled command-line target.
  Rationale: a shell launcher can stay tiny, use the app’s stable bundle identifier, avoid multi-target signing complexity, and still satisfy the requested `qmv ..` workflow.

- Decision: have the installed launcher resolve the target directory locally, then call Launch Services with the app bundle identifier instead of hard-coding an app path or relying on ad hoc launch arguments.
  Rationale: using `open -b com.souschefstudio.Free-Markdown-Viewer <directory>` stays compatible with App Store installs, app renames, and normal macOS "open document/folder" routing.

- Decision: standardize on `~/.local/bin/qmv` instead of a user-chosen PATH directory.
  Rationale: the fixed location is a better fit for user guidance, PATH follow-up automation, and predictable reinstall/remove behavior, while still staying inside a user-writable per-account location.

- Decision: ask for one-time access to the user's home folder and persist that approval with a security-scoped bookmark.
  Rationale: the app needs permission to create `~/.local/bin` when it does not exist and to remove/reinstall `qmv` later without re-prompting every time.

- Decision: package the PATH-fix logic as a bundled shell resource and copy a short `/bin/sh <resource>` command instead of the full script body.
  Rationale: the shorter command is easier for users to copy/paste, while the script stays versioned with the app and remains directly inspectable in the bundle.

- Decision: use `com.apple.security.files.user-selected.read-write` together with `com.apple.security.files.user-selected.executable` for the macOS target.
  Rationale: the CLI installer is an explicitly user-triggered write flow, and read-only access cannot satisfy the actual launcher export into `~/.local/bin`.

- Decision: use a macOS-specific `Info-macOS.plist` for the app target instead of relying on generated plist settings for `CFBundleDocumentTypes`.
  Rationale: the generated-plist build-setting path did not emit the folder document type reliably, while the explicit plist makes the Launch Services contract inspectable and deterministic.

- Decision: add both a menu item and a no-workspace-screen affordance, and gate the empty-state button on the launcher not already being installed.
  Rationale: the menu item satisfies the explicit install request, while the empty-state button makes the feature discoverable exactly where new macOS users land.

- Decision: preserve existing open windows by treating CLI-opened directories as window-scoped workspace opens rather than a global workspace replacement.
  Rationale: the repository already has window-scoped session infrastructure, and replacing unrelated windows would be a surprising regression for a multi-window macOS app.

## Outcomes & Retrospective

The macOS app now supports the end-to-end Terminal flow requested in this workstream. Users can install `qmv` from `File > Install Command Line Tool…` or from the empty-window screen, and the installer now always targets `~/.local/bin/qmv`. When the sandbox does not yet have write access, the app explains why, prompts the user to approve access to the home folder once, persists that approval as a security-scoped bookmark, then creates `~/.local/bin` if needed and writes the launcher there. After install, the app now shows a short `/bin/sh ...` command that points to a bundled `qmv-finish-terminal-setup.sh` resource inside the app instead of dumping the entire PATH-fix script inline. The installed launcher resolves the requested directory locally and calls `open -b com.souschefstudio.Free-Markdown-Viewer <directory>`, so `qmv ..` reopens Quick Markdown Viewer to the parent folder without depending on a hard-coded app path.

The app also now accepts Launch Services folder-open events directly. If the app is launched into an empty window, the incoming CLI-opened folder is consumed by that window; if the app already has an active workspace, the folder is opened into a fresh window-scoped session instead of clobbering an unrelated window. That preserves the repo’s existing multiwindow behavior while making the CLI useful on a running app.

The main design correction from planning held: there is still no silent App Store auto-install. Instead, the shipped implementation uses an explicit user-selected install flow plus `com.apple.security.files.user-selected.executable`, which matches the sandbox guidance and gives App Review a clear story for why the entitlement exists.

## Context and Orientation

Existing implementation surfaces relevant to this work:

- `Quick Markdown Viewer/Quick Markdown Viewer/Quick_Markdown_ViewerApp.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/WindowSceneRootView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/WorkspaceWindowSessionStore.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/WorkspaceSecurityScope.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/Harness/AccessibilityIDs.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj/project.pbxproj`
- `docs/release/app-review-notes.md`

The stable bundle identifier currently used across the repository and release notes is `com.souschefstudio.Free-Markdown-Viewer`. The CLI launcher should target that identifier so the shell command is decoupled from display-name changes.

The v1 launcher should support these user-facing cases:

1. `qmv ..` opens the parent directory.
2. `qmv /absolute/path/with spaces` opens a directory with spaces safely.
3. `qmv some-file.md` resolves to that file’s containing folder or fails with a clear error, depending on the final script policy chosen during implementation.
4. invoking `qmv` while the app is already running opens the requested workspace without discarding unrelated windows.
5. removing the installed launcher causes the app to return to the "not installed" UI state.

## Plan of Work

1. Add a macOS-facing external-open intake path so Quick Markdown Viewer can accept folders opened through Launch Services, not only folders chosen from `NSOpenPanel`.
2. Add a macOS CLI-installer service that can generate the `qmv` launcher, write it to `~/.local/bin/qmv`, persist install status plus the one-time access token needed to manage that location, and safely detect when the launcher is missing or stale.
3. Surface the installer in the macOS command menu and in the no-workspace empty state with the requested one-line explanation.
4. Add focused unit/UI regression coverage for install-state detection, launcher generation, and CLI-triggered workspace opening.
5. Update release/review notes and verify the signed entitlement surface if executable-export support changes the app target configuration.

## Concrete Steps

1. Extend the macOS app lifecycle in `Quick Markdown Viewer/Quick Markdown Viewer/Quick_Markdown_ViewerApp.swift` and/or `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/WindowSceneRootView.swift` so incoming directory-open events can be routed into the existing window/session model rather than being ignored.
2. Thread external directory-open requests through `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift` and `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/WorkspaceWindowSessionStore.swift`, preserving the existing window-scoped workspace behavior when multiple windows already exist.
3. Add a macOS-only installer helper inside the app target that:
   - renders deterministic `qmv` script contents,
   - validates the fixed `~/.local/bin/qmv` destination and the user-approved home-folder grant,
   - writes the launcher as a non-quarantined executable after explicit user approval,
   - records enough state to tell whether the launcher is still installed.
4. Update `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/WindowSceneRootView.swift`, `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift`, and `Quick Markdown Viewer/Quick Markdown Viewer/Harness/AccessibilityIDs.swift` to expose:
   - `Install Command Line Tool…` in the macOS menu,
   - a macOS empty-state button when the launcher is absent,
   - a one-line explanation such as `Install \`qmv\` to open folders from Terminal.`
5. Update the Xcode target configuration in `Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj/project.pbxproj` as needed for executable export, and reflect any App Review-facing sandbox change in `docs/release/app-review-notes.md`.
6. Add focused coverage in `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift` and `Quick Markdown Viewer/Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests.swift` for:
   - launcher script generation and path handling,
   - install-status visibility,
   - opening a workspace via the CLI-triggered directory-open path.

## Validation and Acceptance

Acceptance for this workstream requires:

- a user can install a `qmv` launcher from inside the macOS app to `~/.local/bin/qmv` after explicitly approving access to the home folder when the sandbox needs it
- `qmv ..` opens the parent directory in Quick Markdown Viewer
- directory paths containing spaces are handled correctly by the installed launcher
- invoking the launcher while the app is already running opens the requested workspace without clobbering unrelated open windows
- the app does not attempt silent CLI installation during App Store install or first launch
- when the launcher is not installed, the macOS menu item is available and the empty-window screen shows the one-line installer explanation plus action button
- the app’s signed macOS entitlements remain minimal and intentional; if executable export support adds `com.apple.security.files.user-selected.executable`, archive inspection confirms it alongside the existing sandbox/user-selected access
- targeted validation passes, plus `python3 scripts/check_execplan.py` and `python3 scripts/knowledge/check_docs.py`

## Idempotence and Recovery

The installer flow should be idempotent. Reinstalling the launcher to the same path should overwrite the generated script atomically rather than creating duplicates. If the chosen install destination later disappears, loses execute bits, or no longer matches the generated launcher contents, the app should fall back to a "not installed" state and offer installation again instead of pretending the CLI is still available.

If executable-export entitlements cause App Review concern, the recovery path is to keep the Launch Services folder-open support and downgrade the installer to an explicit export flow that writes the launcher only after a one-time user-approved folder grant with updated review notes. The plan intentionally avoids privileged installers, background daemons, and system-wide writes outside explicit user choice.

## Artifacts and Notes

Validation commands run:

- `./scripts/test-unit`
- `./scripts/test-ui-macos --smoke`
- `python3 scripts/check_execplan.py docs/exec-plans/active/2026-04-16-macos-cli-open-folder-launcher.md`
- `python3 scripts/knowledge/check_docs.py`

External references used during planning:

- Apple Developer Documentation: `https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox`
- Apple Entitlement Key Reference: `https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html`

The generated launcher should use the repository’s current bundle identifier rather than the display name, so app renames do not require users to reinstall `qmv`.

## Interfaces and Dependencies

This work depends on:

- SwiftUI macOS scene and command APIs already used in the app shell
- AppKit lifecycle hooks for incoming folder-open events
- the existing `AppModel` and `WorkspaceWindowSessionStore` workspace/session wiring
- Launch Services behavior for opening folders into an app by bundle identifier
- App Sandbox user-selected file access, security-scoped bookmarks, and any entitlement updates needed to export a runnable launcher

No third-party runtime dependencies are expected. The intended CLI implementation should stay repo-owned and minimal.
