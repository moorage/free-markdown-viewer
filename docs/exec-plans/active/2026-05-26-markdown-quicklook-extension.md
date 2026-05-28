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

## Surprises & Discoveries

- The macOS app already declares `net.daringfireball.markdown` as its Markdown document type.
  Evidence: `Quick Markdown Viewer/Info-macOS.plist` includes `CFBundleDocumentTypes` with `LSItemContentTypes = net.daringfireball.markdown`.

- Xcode platform filtering for the embedded extension must use the plural `platformFilters = (macos, );` key on both the embed build file and target dependency. A singular `platformFilter = macos;` entry still let the iOS build attempt to embed the macOS `.appex`.

- The extension target has default MainActor isolation enabled, so the file-reading helper must be explicitly `nonisolated` before it is called from a detached task.

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

## Outcomes & Retrospective

Implemented. The macOS app target now embeds `Quick Markdown Viewer QuickLook.appex`, whose processed Info.plist declares `com.apple.quicklook.preview` and supports `net.daringfireball.markdown`. The preview controller reads the requested file off the main actor, decodes common Markdown encodings, formats with native `AttributedString(markdown:)`, and displays the result in a read-only AppKit text view.

The target is macOS-only and platform-filtered so the universal app scheme continues to build for iOS without embedding the `.appex`. Focused tests cover the extension declarations, project wiring, and native-rendering constraints. The remaining operational caveat is normal macOS behavior: users can still choose a different Quick Look provider or disable extensions in System Settings.

## Context and Orientation

Relevant files:

- `Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj/project.pbxproj`
- `Quick Markdown Viewer/Quick Markdown Viewer QuickLook/PreviewViewController.swift`
- `Quick Markdown Viewer/QuickLookPreview-Info.plist`
- `Quick Markdown Viewer/Info-macOS.plist`
- `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift`

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

## Validation and Acceptance

Acceptance requires:

- The macOS app bundle contains a Quick Look Preview extension product under `Contents/PlugIns`.
- The extension declares `com.apple.quicklook.preview` and supports Markdown content types.
- Markdown preview rendering uses native AppKit/SwiftUI/text rendering, not `WKWebView`, HTML/CSS/JS, or external renderer subprocesses.
- The extension is bundled/enabled by default; no separate installer action is required.
- Focused metadata/rendering tests pass.
- macOS debug build, `python3 scripts/check_execplan.py`, `python3 scripts/knowledge/check_docs.py`, and relevant `git diff --check` pass.

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

## Interfaces and Dependencies

- Quick Look extension point: `com.apple.quicklook.preview`.
- Markdown UTI used by the app: `net.daringfireball.markdown`.
- macOS host APIs: QuickLookUI/AppKit inside the extension only.
- Native parser dependency: Foundation `AttributedString(markdown:)` inside the extension target.
- The extension must not introduce web rendering or JavaScript dependencies.
