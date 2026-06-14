# Markdown Quick Look Extension

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

Quick Markdown Viewer should optionally act as the system Quick Look provider for Markdown files on macOS. The extension should be bundled with the app so it is enabled by default after installation or launch-services registration, without a separate installer step. Finder Quick Look should preview `.md`, `.markdown`, `.mdown`, `.mkd`, and `.mkdn` documents with a native rendered surface, not raw source and not HTML/WebKit.

The implementation should preserve existing app behavior and platform boundaries: Quick Look code is macOS-only, shared Markdown parsing stays platform-neutral, and no `WKWebView`, JavaScript, HTML/CSS renderer, or remote service is introduced.

## Progress

- [x] (2026-05-26 05:24Z) Created this ExecPlan before implementing the Quick Look extension.
- [x] (2026-05-26 05:41Z) Added a macOS-only `Quick Markdown Viewer QuickLook` app-extension target, native preview controller source, and Quick Look Info.plist declarations.
- [x] (2026-05-26 05:50Z) Added focused unit coverage for extension metadata, project embedding, macOS platform filtering, and no-WebKit/no-JavaScript rendering constraints.
- [x] (2026-05-26 06:02Z) Verified the macOS app bundle embeds the Quick Look extension under `Contents/PlugIns` and the iOS simulator app does not embed the macOS extension.
- [x] (2026-05-26 06:09Z) Updated architecture, README, and implementation notes for the new Quick Look subsystem.
- [x] (2026-06-05 17:34Z) Investigated reported regressions where Quick Look previews read like raw Markdown and dragging/opening a Markdown file loads the containing folder without selecting or rendering that file.
- [x] (2026-06-05 17:50Z) Replaced the Quick Look single-blob formatter with an extension-local native block formatter covering supported fixture Markdown, Mermaid, CSV, and TSV files.
- [x] (2026-06-05 17:50Z) Hardened Launch Services file opens by carrying the explicit selected file URL into local workspace loading so the selected file appears even when parent-folder enumeration is limited.
- [x] (2026-06-05 17:50Z) Verified focused unit tests, macOS build, built extension metadata, and Computer Use inspection of the built app opening `Fixtures/docs/basic_typography.md`.
- [x] (2026-06-05 18:00Z) Added a compact Quick Look `Rendered` / `Source` segmented control and runtime coverage that switches between the rendered Markdown preview and raw source text.
- [x] (2026-06-05 19:00Z) Added a Quick Look feature-parity spec plus runtime coverage for inline Mermaid fences and local image attachments.
- [x] (2026-06-05 19:18Z) Fixed Quick Look Mermaid rendered mode so inline and standalone Mermaid previews draw a bounded native diagram image attachment instead of displaying raw `flowchart` source text.
- [x] (2026-06-14 00:00Z) Fixed Quick Look rendered mode for embedded Markdown pipe tables with inline formatting and escaped pipe characters.

## Surprises & Discoveries

- The macOS app already declares `net.daringfireball.markdown` as its Markdown document type.
  Evidence: `Quick Markdown Viewer/Info-macOS.plist` includes `CFBundleDocumentTypes` with `LSItemContentTypes = net.daringfireball.markdown`.

- Xcode platform filtering for the embedded extension must use the plural `platformFilters = (macos, );` key on both the embed build file and target dependency. A singular `platformFilter = macos;` entry still let the iOS build attempt to embed the macOS `.appex`.

- The extension target has default MainActor isolation enabled, so the file-reading helper must be explicitly `nonisolated` before it is called from a detached task.

- The current Quick Look formatter parses the whole document with Foundation `AttributedString(markdown:)` and then applies one broad body paragraph style. In practice this can flatten the visual hierarchy enough that Finder Quick Look does not look meaningfully Markdown-rendered.

- Real Launch Services file opens can arrive before the SwiftUI window has finished bootstrapping. If the app consumes the request in the wrong window/timing, the containing folder may load while the requested file selection is lost, leaving no sidebar selection and no document pane.

- Opening the installed `/Applications/Quick Markdown Viewer.app` through Launch Services reproduced the stale empty-folder symptom, while targeting the just-built app bundle by absolute path showed the fixed behavior. Evidence: Computer Use first saw the installed app at `/Applications/Quick Markdown Viewer.app` with an `app-store` empty workspace, then saw the built app at `artifacts/DerivedData/Build/Products/Debug/Quick Markdown Viewer.app` with `Fixtures/docs > basic_typography.md`, sidebar rows, and rendered main-pane text.

- Quick Look can host controls inside the extension-provided view, but the surrounding Quick Look window chrome remains system-owned. The mode switch therefore belongs in the preview controller's content view.

- `NSViewController.loadViewIfNeeded()` is only available on macOS 14+, while this target still builds for macOS 13. The extension test hook uses normal lazy `view` access instead.

- The app parser already converts inline Mermaid fences to `mermaidDiagram` blocks and local image markdown to hydrated image blocks. Quick Look must mirror those recognizers, but with bounded preview behavior instead of the app's full interactive Mermaid graph/zoom and media surfaces.

- The first Quick Look Mermaid parity pass was still too source-like: it labeled Mermaid content but displayed the raw `flowchart LR` body in rendered mode. The regression test now requires a native image attachment and rejects raw Mermaid source text in rendered mode.

- Quick Look table coverage previously only required supported fixtures to produce non-empty output, so rendered mode could regress by showing raw inline Markdown syntax inside table cells. A focused runtime test now loads the built `.appex` and rejects raw pipe-divider, code-span, and strong-emphasis syntax in rendered table output.

## Decision Log

- Decision: Bundle a Quick Look Preview extension target instead of trying to install a separate user-level generator.
  Rationale: modern macOS uses app extensions for Quick Look; bundling the extension makes the feature available by default with the app and avoids extra installer state.
  Date/Author: 2026-05-26 / Codex

- Decision: Keep the first Quick Look preview read-only and native-rendered.
  Rationale: Quick Look is for previewing a single file, so it should reuse parsing/formatting without workspace navigation, editing, or external media fetch behavior.
  Date/Author: 2026-05-26 / Codex

- Decision: Use a lightweight extension-local formatter based on Foundation `AttributedString(markdown:)` and an AppKit `NSTextView`, rather than linking the full app renderer into the `.appex`.
  Rationale: The extension needs a safe single-file preview with a small dependency surface. Pulling the full app renderer would increase target coupling and risk bringing workspace/media behavior into Quick Look.
  Date/Author: 2026-05-26 / Codex

- Decision: Treat "enabled by default" as bundling and embedding the Quick Look Preview extension in the macOS app, not as an app-managed toggle.
  Rationale: macOS owns Quick Look extension registration and user enable/disable state. The app should ship the extension and let System Settings/Finder control selection.
  Date/Author: 2026-05-26 / Codex

- Decision: Improve Quick Look with an extension-local native block formatter instead of linking the full app renderer into the `.appex`.
  Rationale: Finder preview needs clear Markdown hierarchy for headings, lists, quotes, code, tables, media references, and Mermaid files, but the extension should stay small and avoid workspace/media behavior.
  Date/Author: 2026-06-05 / Codex

- Decision: Put the `Rendered` / `Source` mode switch inside the Quick Look preview view.
  Rationale: Quick Look lets preview extensions provide their own AppKit view hierarchy, but macOS owns the outer preview panel. A small segmented control gives the requested view switching without depending on private Quick Look chrome.
  Date/Author: 2026-06-05 / Codex

- Decision: Add a documented Quick Look feature-parity matrix with explicit performance limits.
  Rationale: The app and Quick Look should agree on document feature recognition, while Quick Look deliberately avoids network fetches, animation/playback, full Mermaid graph layout, and other heavyweight preview work.
  Date/Author: 2026-06-05 / Codex

- Decision: Render Quick Look Mermaid as an extension-local AppKit raster diagram attachment.
  Rationale: The app's full interactive Mermaid SwiftUI surface is not packaged as a reusable framework for the `.appex`, and Quick Look should stay bounded. A native AppKit raster preview gives Finder a real rendered diagram while leaving zoom, pan, detached windows, and heavier layout to the app.
  Date/Author: 2026-06-05 / Codex

- Decision: Keep Quick Look Markdown table rendering extension-local, but normalize inline Markdown cell text and split escaped pipe characters correctly.
  Rationale: Finder previews need rendered-mode table readability without linking the full app renderer into the `.appex`. Normalizing cells in the existing monospaced native table path fixes the reported embedded-table issue with a small, bounded change.
  Date/Author: 2026-06-14 / Codex

## Outcomes & Retrospective

Implemented. The macOS app target now embeds `Quick Markdown Viewer QuickLook.appex`, whose processed Info.plist declares `com.apple.quicklook.preview` and supports Markdown, Mermaid, CSV, and TSV content types. The preview controller reads the requested file off the main actor, decodes common Markdown encodings, formats with native text surfaces, and displays the result in a read-only AppKit text view.

The target is macOS-only and platform-filtered so the universal app scheme continues to build for iOS without embedding the `.appex`. Focused tests cover the extension declarations, project wiring, and native-rendering constraints. The remaining operational caveat is normal macOS behavior: users can still choose a different Quick Look provider or disable extensions in System Settings.

2026-06-05 follow-up: Quick Look now renders Markdown through an extension-local native block formatter rather than relying on a single document-wide attributed string. The formatter gives visible hierarchy to headings, paragraphs, lists, quotes, code fences, Markdown tables, image/video references, standalone Mermaid files, CSV, and TSV. The extension metadata now advertises Markdown, Mermaid, CSV, and TSV content types, and runtime unit coverage loads the built `.appex` formatter over every supported fixture document under `Fixtures/docs` and `Fixtures/app-store`.

2026-06-05 mode-switch follow-up: Quick Look previews now include a native AppKit segmented control with `Rendered` and `Source` modes. The controller reads the file once, caches both attributed strings, defaults to the rendered view, and swaps the existing text view content when the user changes modes. Runtime extension coverage verifies the control labels, selected segment, raw `# Basic typography` source view, and return to rendered Markdown.

2026-06-05 parity follow-up: `docs/quicklook-feature-parity.md` now defines the app-vs-Quick-Look feature matrix. Inline Mermaid fences in Markdown now render as bounded native diagram image attachments instead of generic code fences or raw Mermaid source, and local inline images now render as scaled native `NSTextAttachment` previews with captions. Remote/data images, videos, animation playback, Mermaid zoom/pan/detached windows, and linked-media navigation remain intentionally limited to keep Finder previews lightweight.

2026-06-14 table follow-up: Quick Look rendered mode now handles embedded Markdown pipe tables with inline code, strong text, and escaped pipe characters. The extension-local table formatter strips rendered inline Markdown syntax from cells before calculating monospaced column widths, so rendered previews no longer show raw table dividers or raw code/emphasis markers for this path.

The app file-open path now preserves the exact selected file URL in `ExternalWorkspaceOpenRequest`; `LocalWorkspaceProvider` exposes that file as an explicit workspace member and read target if parent-folder enumeration skips it. This fixes the user-visible app-icon/open-file case where the folder title could load without a sidebar item or main-pane document.

## Context and Orientation

Relevant files:

- `Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj/project.pbxproj`
- `Quick Markdown Viewer/Quick Markdown Viewer QuickLook/PreviewViewController.swift`
- `Quick Markdown Viewer/QuickLookPreview-Info.plist`
- `Quick Markdown Viewer/Info-macOS.plist`
- `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift`
- `docs/quicklook-feature-parity.md`

Current behavior:

- The app can open Markdown files and folders.
- Markdown file extensions are recognized in `WorkspaceDocumentKind`.
- Rendered selectable text is already available through shared parsing plus macOS platform text formatting.
- The project now has a macOS-only Quick Look Preview extension target embedded in the app's `Embed App Extensions` phase.

## Plan of Work

1. Add a macOS Quick Look Preview extension target that is embedded in the app bundle.
2. Declare Markdown UTIs/content types in the extension Info.plist so Finder can route Markdown Quick Look requests to it.
3. Reuse native platform parsing/formatting where possible, keeping AppKit in the extension host.
4. Add an app-visible option or status affordance only if the platform supports meaningful app control; otherwise document that bundling is the default-enabled option and user disabling lives in System Settings.
5. Add focused tests that validate extension metadata and renderer behavior without requiring Finder automation.
6. Build the macOS app and verify the extension product is embedded in `Contents/PlugIns`.

## Concrete Steps

1. Inspect the Xcode project structure and determine the least risky manual `project.pbxproj` changes for a new app-extension target.
2. Add `QuickLookPreview/` sources and Info.plist under the app project.
3. Implement a `QLPreviewingController`-backed preview controller that reads the file URL, parses Markdown, and displays a native text preview.
4. Add unit tests for extension Info.plist declarations and supported Markdown extensions/content types.
5. Build the macOS target and inspect the built app bundle for the Quick Look extension.
6. Update `.agents/DOCUMENTATION.md`, this ExecPlan, and run validation scripts.
7. Replace the single-blob Quick Look preview formatter with a native block renderer and fixture-backed tests.
8. Reproduce and harden file-open selection so dragging or Launch Services opening a Markdown file selects that file in the sidebar and renders it in the main pane.
9. Add a Quick Look-local rendered/source mode switch and runtime test coverage for both modes.
10. Add a Quick Look feature-parity spec and bounded-preview coverage for inline Mermaid and local images.

## Validation and Acceptance

Acceptance requires:

- The macOS app bundle contains a Quick Look Preview extension product under `Contents/PlugIns`.
- The extension declares `com.apple.quicklook.preview` and supports Markdown content types.
- Markdown preview rendering uses native AppKit/SwiftUI/text rendering, not `WKWebView`, HTML/CSS/JS, or external renderer subprocesses.
- The extension is bundled/enabled by default; no separate installer action is required.
- Focused metadata/rendering tests pass.
- macOS debug build, `python3 scripts/check_execplan.py`, `python3 scripts/knowledge/check_docs.py`, and relevant `git diff --check` pass.
- Every supported document in `Fixtures/docs`, including nested Mermaid fixtures, can be rendered through the Quick Look formatter without falling back to raw source-only output.
- A macOS UI verification opens a Markdown file from `Fixtures/docs` through the app bundle path and confirms the containing folder, sidebar node, and main pane selection all show the requested file.
- The Quick Look preview view can switch between rendered Markdown and raw source without rereading the file.
- Inline Mermaid fences are recognized in Markdown Quick Look previews and do not show raw fence markers in rendered mode.
- Local inline image Markdown produces a native image attachment in rendered Quick Look previews, while remote/heavy media behavior remains explicitly limited by spec.
- Embedded Markdown pipe tables in Quick Look rendered mode show native monospaced table text with inline cell syntax resolved and escaped pipe characters kept inside cells.

## Idempotence and Recovery

The change should be reversible by removing the extension target, embedded extension build phase entry, new source directory, and tests. The app's existing document-opening behavior should not depend on the extension target, so app launch remains recoverable if Quick Look registration fails.

## Artifacts and Notes

Commands run from `/Users/matthewmoore/Projects/free-markdown-viewer`:

- `plutil -lint "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj/project.pbxproj" "Quick Markdown Viewer/QuickLookPreview-Info.plist"`
- `xcodebuild -list -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj"`
- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-quicklook-tests2 -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testQuickLookPreviewExtensionDeclaresMarkdownSupport" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testQuickLookPreviewExtensionTargetIsEmbeddedForMacOS" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testQuickLookPreviewSourceUsesNativeMarkdownRendering" test`
- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-quicklook-macos2 -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build`
- `xcodebuild -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-quicklook-ios2 -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build`
- `find "/tmp/qmv-quicklook-macos2/Build/Products/Debug/Quick Markdown Viewer.app/Contents/PlugIns" -maxdepth 3 -type d | sort`
- `plutil -p "/tmp/qmv-quicklook-macos2/Build/Products/Debug/Quick Markdown Viewer.app/Contents/PlugIns/Quick Markdown Viewer QuickLook.appex/Contents/Info.plist"`
- `python3 scripts/check_execplan.py`
- `python3 scripts/knowledge/check_docs.py`
- `git diff --check`
- `xcodebuild -quiet -project 'Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj' -scheme 'Quick Markdown Viewer' -configuration Debug -derivedDataPath /tmp/qmv-quicklook-open-fix-tests -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= '-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testExternalWorkspaceOpenCoordinatorNormalizesMarkdownFileToWorkspaceAndSelection' '-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testExternalWorkspaceOpenCoordinatorCanForceNewWindowForDroppedMarkdownFile' '-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testExternalWorkspaceOpenCoordinatorNormalizesCSVFileToWorkspaceAndSelection' '-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testWorkspaceProviderIncludesExplicitOpenedFileEvenWhenEnumerationSkipsIt' '-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testAppModelOpenFolderSelectsExplicitOpenedFileWhenEnumerationSkipsIt' '-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testQuickLookPreviewExtensionDeclaresMarkdownSupport' '-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testQuickLookPreviewSourceUsesNativeMarkdownRendering' '-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testQuickLookPreviewExtensionRendersBasicMarkdownAsStyledPreview' '-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testQuickLookPreviewExtensionRendersEverySupportedFixtureDocument' test`
- `./scripts/build --platform macos`
- `plutil -p 'artifacts/DerivedData/Build/Products/Debug/Quick Markdown Viewer.app/Contents/PlugIns/Quick Markdown Viewer QuickLook.appex/Contents/Info.plist'`
- `osascript -e 'tell application "/Users/matthewmoore/Projects/free-markdown-viewer/artifacts/DerivedData/Build/Products/Debug/Quick Markdown Viewer.app" to open POSIX file "/Users/matthewmoore/Projects/free-markdown-viewer/Fixtures/docs/basic_typography.md"'`
- Computer Use `get_app_state` for `/Users/matthewmoore/Projects/free-markdown-viewer/artifacts/DerivedData/Build/Products/Debug/Quick Markdown Viewer.app` showed `Fixtures/docs > basic_typography.md`, sidebar row `basic_typography.md`, and rendered document text.
- `xcodebuild -quiet -project 'Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj' -scheme 'Quick Markdown Viewer' -configuration Debug -derivedDataPath /tmp/qmv-quicklook-switch-tests -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= '-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testQuickLookPreviewSourceUsesNativeMarkdownRendering' '-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testQuickLookPreviewExtensionRendersBasicMarkdownAsStyledPreview' '-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testQuickLookPreviewExtensionCanSwitchBetweenRenderedAndSourceViews' '-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testQuickLookPreviewExtensionRendersEverySupportedFixtureDocument' test`
- `qlmanage -r && qlmanage -p 'Fixtures/docs/basic_typography.md'`; Computer Use saw `qlmanage` running but `get_app_state` timed out, so live Quick Look panel introspection remains less reliable than the runtime `.appex` tests.
- `xcodebuild -quiet -project 'Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj' -scheme 'Quick Markdown Viewer' -configuration Debug -derivedDataPath /tmp/qmv-quicklook-parity-tests -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= '-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testQuickLookFeatureParitySpecDocumentsBoundedPreviewContract' '-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testQuickLookPreviewExtensionRendersInlineMermaidFenceAsBoundedPreview' '-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testQuickLookPreviewExtensionRendersLocalImagesAsAttachments' '-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testQuickLookPreviewExtensionRendersEverySupportedFixtureDocument' '-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testQuickLookPreviewSourceUsesNativeMarkdownRendering' test`
- `xcodebuild -quiet -project 'Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj' -scheme 'Quick Markdown Viewer' -configuration Debug -derivedDataPath /tmp/qmv-quicklook-table-tests -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= '-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testQuickLookPreviewExtensionRendersMarkdownTablesInRenderedMode' '-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testQuickLookPreviewExtensionRendersBasicMarkdownAsStyledPreview' '-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testQuickLookPreviewExtensionRendersEverySupportedFixtureDocument' test`
- `python3 scripts/check_execplan.py`
- `python3 scripts/knowledge/check_docs.py`
- `git diff --check`
- `./scripts/test-unit`

## Interfaces and Dependencies

- Quick Look extension point: `com.apple.quicklook.preview`.
- Markdown UTI used by the app: `net.daringfireball.markdown`.
- macOS host APIs: QuickLookUI/AppKit inside the extension only.
- Native parser dependency: Foundation `AttributedString(markdown:)` inside the extension target.
- The extension must not introduce web rendering or JavaScript dependencies.
