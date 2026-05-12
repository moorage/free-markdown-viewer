# Markdown Outline Inspector

## Purpose / Big Picture

Users should be able to open a right-side outline surface while reading Markdown and jump to headings without reloading or reparsing the document on the main thread. The outline should derive from the same parsed Markdown blocks as the rendered document, stay empty for CSV/TSV documents, and preserve native SwiftUI navigation patterns across macOS, iPad, and iPhone.

## Progress

- [x] (2026-05-12T00:00Z) Confirmed document parsing already happens in `AppModel.loadDocument` on a detached task and the detail pane can scroll block views by stable block IDs.
- [x] (2026-05-12T19:22Z) Added an outline value model and generate heading items off the main actor as part of document load.
- [x] (2026-05-12T19:22Z) Added an openable right-side outline surface with a toolbar/top-bar button and heading rows.
- [x] (2026-05-12T19:22Z) Wired heading clicks to scroll the main document pane to the matching block ID.
- [x] (2026-05-12T19:22Z) Added focused tests and validation evidence.
- [x] (2026-05-12T20:27Z) Preserved inline-code spans in outline titles so right-side headings render backtick text with a monospaced font and correct spacing.
- [x] (2026-05-12T20:36Z) Added active-section tracking so a visible outline highlights the heading section currently at the top of the reader.
- [x] (2026-05-12T22:35Z) Added a visible active state to the outline toolbar/top-bar button while the outline drawer or sheet is open.
- [x] (2026-05-12T23:02Z) Added a draggable resize handle for the inline outline pane on macOS and regular-width iOS/iPad layouts.
- [x] (2026-05-12T23:18Z) Replaced the custom macOS resize handle with native `HSplitView` resizing after the custom handle let window dragging win.

## Surprises & Discoveries

- Observation: plain Markdown documents currently use `SelectableDocumentTextView` unless they contain code, tables, media, or task-list blocks.
  Evidence: `AppModel.shouldRenderStructuredContent(for:)` only returns true for those richer block kinds.
- Observation: the local Xcode install reports an out-of-date CoreSimulator framework, but macOS-hosted unit tests still run.
  Evidence: focused `xcodebuild ... test` emitted `CoreSimulator is out of date` and then completed the selected macOS tests successfully.
- Observation: after installing the iOS simulator runtime, iOS build and smoke validation now pass on healthy simulator devices.
  Evidence: `./scripts/build --platform ios` succeeded against the iOS 26.5 iPhone simulator, `./scripts/test-ui-ios --device both --smoke` passed the iPhone checkpoint and built iPad, and a manual iPad smoke run passed on the iOS 26.5 `iPad (A16)` simulator; the preferred `iPad Pro 11-inch (M5)` simulator hung in `simctl install`/`simctl launch`.
- Observation: `MarkdownBlock.plainText` is not enough for outline display because it removes inline-code semantics.
  Evidence: a heading like ``## Use `qmv /tmp/file.md` correctly`` needs the code span rendered monospace in the outline while the jump/search title remains `Use qmv /tmp/file.md correctly`.
- Observation: active-section tracking must not measure every rendered block.
  Evidence: heading offsets are emitted only for heading blocks, and only while the outline is presented, so large paragraphs and tabular blocks do not add geometry-preference churn.
- Observation: compact iPhone presentation has no persistent right-side pane to resize.
  Evidence: `outlineSheetBinding` presents the outline as a sheet only when `isCompactPhoneLayout` is true; the resizable pane is restricted to `shouldShowInlineOutline`.
- Observation: the custom SwiftUI drag handle is not reliable on macOS in this window.
  Evidence: dragging the handle moved the whole window instead of resizing the outline, so the mouse drag was being claimed by window dragging rather than the SwiftUI `DragGesture`.

## Decision Log

- Decision: generate the outline from parsed `MarkdownBlock` headings inside the existing detached document-load task.
  Rationale: this avoids a second parse and keeps outline generation off the main actor.
- Decision: use stable `MarkdownBlock.id` values as scroll targets.
  Rationale: the renderer already gives each block a deterministic identity, and SwiftUI `ScrollViewReader` can scroll to those IDs without adding anchor math.
- Decision: render Markdown with an outline through the block scroll view even when it would otherwise use the selectable text view.
  Rationale: heading jumps require block-level scroll targets; preserving native `Text` selection inside the block scroll view is the smallest implementation that makes jumps reliable.
- Decision: keep the previous active outline item when no newly measured heading has reached the top threshold.
  Rationale: lazy stacks may stop reporting an already-scrolled heading; retaining the prior active section avoids highlighting the next heading too early.
- Decision: keep outline resizing as local shell state with min/max clamping rather than persisting it.
  Rationale: this is a layout affordance, not document data; clamping keeps the document readable across macOS and iPad window sizes without adding storage or migration concerns.
- Decision: use native `HSplitView` for macOS outline resizing and keep the custom handle for iOS/iPad only.
  Rationale: `HSplitView` owns AppKit split-divider mouse tracking and avoids conflicts with window dragging; iOS has no AppKit split divider and still needs the SwiftUI drag/touch handle.

## Outcomes & Retrospective

Markdown documents now publish `outlineItems` from the detached document-load path. The toolbar/top bar shows a document-outline button when headings exist. Regular-width layouts open a right-side outline panel; compact iPhone layouts present the same outline as a sheet. Selecting a heading sets a block ID scroll target, and `DocumentBlockScrollView` uses `ScrollViewReader` to scroll to the matching rendered block.

Outline items also carry title runs derived from the heading `AttributedString`. Inline-code runs are rendered in the right-side outline with `ViewerFont.monospacedBody`, while normal runs use `ViewerFont.body`; leading and trailing whitespace is trimmed without stripping separator spaces around code spans.

When the outline is open, rendered heading blocks publish their scroll-view-relative offsets through SwiftUI preferences. The shell resolves those offsets to the last heading at the top threshold, keeps the current section stable between headings, and highlights the matching outline row with an accent background and leading bar.

The outline toggle also reflects open state directly in the app chrome with accent foreground, a subtle rounded background, and an accessibility value of `Shown` or `Hidden`.

Inline iOS/iPad outline layouts include a draggable separator before the outline panel. Dragging left widens the outline, dragging right narrows it, and keyboard/screen-reader adjustable actions step the width while respecting the same min/max constraints. On macOS, the inline outline uses native `HSplitView` so the platform split divider handles resizing.

## Context and Orientation

Relevant code:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift` owns document load state and block parsing.
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/Models.swift` owns shared value models.
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift` owns the split view, toolbar, detail pane, and document block scroll view.
- `Quick Markdown Viewer/Quick Markdown Viewer/Harness/AccessibilityIDs.swift` owns stable UI identifiers.
- `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift` owns focused model/parser coverage.

## Plan of Work

1. Add `MarkdownOutlineItem` with block ID, title, heading level, and stable identity.
2. Extend the document-load result to include outline items generated from parsed Markdown blocks.
3. Publish outline items on `AppModel` and clear them for no-workspace, empty, and CSV/TSV states.
4. Add an outline button plus a right-side panel for regular layouts and sheet-style presentation where a compact phone cannot afford a permanent right-side panel.
5. Wrap the block scroll view in `ScrollViewReader`, assign `.id(block.id)` to rendered blocks, and scroll when an outline item is selected.
6. Add focused unit coverage for outline extraction and model publication.
7. Track rendered heading offsets and highlight the outline row for the current visible section.
8. Add a draggable, accessible resize handle for the inline outline pane.

## Concrete Steps

From `/Users/matthewmoore/Projects/free-markdown-viewer`:

1. Edit `Models.swift`, `AppModel.swift`, `AccessibilityIDs.swift`, and `ViewerShellView.swift`.
2. Add tests in `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift`.
3. Run `python3 scripts/check_execplan.py`.
4. Run focused unit tests covering outline generation and publication.
5. Run the repository's narrow build/test validation for touched app code.

Validation completed from `/Users/matthewmoore/Projects/free-markdown-viewer`:

1. `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-outline-csv-update-unit -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMarkdownOutlineItemsUseHeadingBlocksInDocumentOrder" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testAppModelPublishesOutlineItemsForLoadedMarkdownDocument" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testDelimitedTextParserUsesPlainTextTableCellsForLargeCSV" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testAppStoreLookupConfigurationBuildsPlatformLookupURL" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testAppUpdateVersionComparisonUsesNumericSegments" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testAppUpdateCheckerManualCheckPromptsWhenAppStoreVersionIsNewer" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testAppUpdateCheckerSkipsAutomaticPromptUntilNextVersion" test`
2. `python3 scripts/check_execplan.py`
3. `python3 scripts/knowledge/check_docs.py`
4. `./scripts/test-unit`
5. `./scripts/build --platform all` (macOS build succeeded; iOS builds were skipped by the script because simulator platform discovery is unavailable)
6. `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/qmv-outline-csv-update-ios-build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build` (blocked by missing simulator runtime for asset catalog compilation)
7. `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -sdk iphoneos -destination "generic/platform=iOS" -configuration Debug -derivedDataPath /tmp/qmv-outline-csv-update-ios-device-build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build` (blocked by missing iOS 26.5 platform)
8. `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-outline-code-runs -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMarkdownOutlineItemsUseHeadingBlocksInDocumentOrder" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMarkdownOutlineItemsPreserveInlineCodeRuns" test`
9. `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-outline-code-runs-build -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build`
10. `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-outline-active-section -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testActiveOutlineBlockIDTracksLastHeadingAtViewportTop" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMarkdownOutlineItemsPreserveInlineCodeRuns" test`
11. `python3 scripts/check_execplan.py docs/exec-plans/active/2026-05-12-markdown-outline-inspector.md`
12. `python3 scripts/knowledge/check_docs.py`
13. `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-outline-active-section-build -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build`
14. `git diff --check`
15. `./scripts/build --platform ios`
16. `./scripts/test-ui-ios --device both --smoke` (iPhone smoke passed; iPad build passed, then the preferred `iPad Pro 11-inch (M5)` simulator hung in `simctl launch`)
17. Manual iPad smoke on `iPad (A16)` simulator `C1DAE170-A0B7-44F1-A23E-B0697677435A` passed and wrote `artifacts/checkpoints/shell-smoke-ipad-manual/`

## Validation and Acceptance

Acceptance:

- A toolbar/top-bar action opens and closes an outline surface.
- The outline lists Markdown headings in document order with indentation by heading level.
- Selecting an outline item scrolls the main document pane to that heading.
- While the outline is visible, the outline row matching the current reader section is highlighted.
- While the outline is visible, the outline toggle itself has a visible active state.
- On macOS and regular-width iOS/iPad layouts, the inline outline pane can be resized without hiding the document.
- Outline generation is done from the detached document-load path and not in SwiftUI `body`.
- CSV/TSV documents do not show stale Markdown outline items.
- Existing Markdown links, media, table rendering, and file navigation remain intact.

## Idempotence and Recovery

The outline is derived state from the current document blocks. If a document reload is canceled, the request ID guard in `AppModel.openFile(_:)` must prevent stale outline items from replacing the active document's outline.

If the outline panel causes layout problems on compact devices, the rollback is to keep outline generation and the toolbar button but present the list as a sheet on all iOS compact layouts.

## Artifacts and Notes

No generated artifacts are expected. Runtime build/test outputs remain under `artifacts/` or the selected Xcode derived-data path.

## Interfaces and Dependencies

- Uses native SwiftUI views only.
- No network dependency.
- No `WKWebView`, HTML, CSS, or JavaScript renderer.
