# Large CSV Performance

## Purpose / Big Picture

Large CSV and TSV documents should remain viewable without freezing the whole app or building every cell view at once. The existing CSV/TSV support should stay native and reuse the current table presentation controls, but standalone delimited documents need a rendering path that avoids eager SwiftUI `Grid` construction for thousands of rows.

## Progress

- [x] (2026-05-12T00:00Z) Confirmed standalone CSV/TSV documents parse into a single `.table` block and the current UI renders that block through a non-lazy `Grid`.
- [x] (2026-05-12T19:22Z) Marked standalone CSV/TSV table cells as plain text so rendering does not repeatedly parse Markdown per cell.
- [x] (2026-05-12T19:22Z) Added a lazily rendered, bounded-height table surface for standalone CSV/TSV documents.
- [x] (2026-05-12T19:22Z) Preserved existing Markdown-table styling and print behavior.
- [x] (2026-05-12T19:22Z) Added focused performance-shape tests and validation evidence.

## Surprises & Discoveries

- Observation: `DelimitedTextDocumentParser` currently creates an `AttributedString` for every CSV/TSV cell.
  Evidence: `markdownCell(_:)` in `TabularDocument.swift` sets `attributedText: AttributedString(value)`.
- Observation: the table UI creates a full SwiftUI `Grid` for every row in the table.
  Evidence: `MarkdownBlockView.tableContent(_:)` iterates all rows inside `Grid`.
- Observation: the local Xcode install reports an out-of-date CoreSimulator framework, but macOS-hosted unit tests still run.
  Evidence: focused `xcodebuild ... test` emitted `CoreSimulator is out of date` and then completed the selected macOS tests successfully.
- Observation: after installing the iOS simulator runtime, iOS build and smoke validation now pass on healthy simulator devices.
  Evidence: `./scripts/build --platform ios` succeeded against the iOS 26.5 iPhone simulator, `./scripts/test-ui-ios --device both --smoke` passed the iPhone checkpoint and built iPad, and a manual iPad smoke run passed on the iOS 26.5 `iPad (A16)` simulator; the preferred `iPad Pro 11-inch (M5)` simulator hung in `simctl install`/`simctl launch`.

## Decision Log

- Decision: keep CSV/TSV parsing in the existing document-load task instead of introducing an additional file streaming subsystem in this milestone.
  Rationale: the immediate crash/lag risk is the eager view tree and per-cell attributed text, and changing provider I/O would affect every local/GitHub read path.
- Decision: render standalone CSV/TSV tables through a dedicated lazy row surface while keeping Markdown tables on the existing document-flow layout.
  Rationale: Markdown tables are usually embedded content and should keep natural document height; standalone CSV/TSV files are table documents and can own their own scrollable table viewport.
- Decision: use plain `Text(verbatim:)` for standalone CSV/TSV cells.
  Rationale: CSV/TSV cells are data, not Markdown; avoiding Markdown parsing for every cell prevents avoidable CPU and memory pressure.

## Outcomes & Retrospective

Standalone CSV/TSV tables now carry `contentKind: .plainText`, and the parser no longer allocates an `AttributedString` for every delimited-text cell. `MarkdownBlockView` keeps Markdown tables on the existing document-flow layout, while standalone CSV/TSV documents render inside a bounded two-axis scroll viewport backed by `LazyVStack` rows. Existing table controls still drive wrap mode, column width, and row height.

## Context and Orientation

Relevant code:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/TabularDocument.swift` parses CSV/TSV text into `MarkdownTable`.
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift` converts delimited documents into a `.table` block.
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift` renders tables and owns wrap/column/row controls.
- `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift` already covers CSV/TSV parsing and document loading.

## Plan of Work

1. Add table metadata that distinguishes Markdown table cells from plain delimited-text cells.
2. Update the CSV/TSV parser to produce plain-text table cells without per-cell `AttributedString` allocation.
3. Add a standalone CSV/TSV table renderer using lazy row construction inside a bounded scrollable viewport.
4. Keep the existing print path and Markdown table path unchanged unless the new metadata requires a targeted signature update.
5. Add tests verifying large CSV parse shape and plain-text table metadata.

## Concrete Steps

From `/Users/matthewmoore/Projects/free-markdown-viewer`:

1. Edit `Models.swift`, `TabularDocument.swift`, `AppModel.swift`, and `ViewerShellView.swift`.
2. Add tests in `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift`.
3. Run `python3 scripts/check_execplan.py`.
4. Run focused unit tests for CSV/TSV parsing and model load.
5. Run the repository's narrow build/test validation for touched app code.

Validation completed from `/Users/matthewmoore/Projects/free-markdown-viewer`:

1. `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-outline-csv-update-unit -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMarkdownOutlineItemsUseHeadingBlocksInDocumentOrder" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testAppModelPublishesOutlineItemsForLoadedMarkdownDocument" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testDelimitedTextParserUsesPlainTextTableCellsForLargeCSV" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testAppStoreLookupConfigurationBuildsPlatformLookupURL" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testAppUpdateVersionComparisonUsesNumericSegments" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testAppUpdateCheckerManualCheckPromptsWhenAppStoreVersionIsNewer" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testAppUpdateCheckerSkipsAutomaticPromptUntilNextVersion" test`
2. `python3 scripts/check_execplan.py`
3. `python3 scripts/knowledge/check_docs.py`
4. `./scripts/test-unit`
5. `./scripts/build --platform all` (macOS build succeeded; iOS builds were skipped by the script because simulator platform discovery is unavailable)
6. `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/qmv-outline-csv-update-ios-build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build` (blocked by missing simulator runtime for asset catalog compilation)
7. `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -sdk iphoneos -destination "generic/platform=iOS" -configuration Debug -derivedDataPath /tmp/qmv-outline-csv-update-ios-device-build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build` (blocked by missing iOS 26.5 platform)
8. `./scripts/build --platform ios`
9. `./scripts/test-ui-ios --device both --smoke` (iPhone smoke passed; iPad build passed, then the preferred `iPad Pro 11-inch (M5)` simulator hung in `simctl launch`)
10. Manual iPad smoke on `iPad (A16)` simulator `C1DAE170-A0B7-44F1-A23E-B0697677435A` passed and wrote `artifacts/checkpoints/shell-smoke-ipad-manual/`

## Validation and Acceptance

Acceptance:

- Standalone CSV/TSV cells render as plain text without Markdown parsing.
- Large standalone CSV/TSV views do not construct all visible row views eagerly.
- Existing Markdown table rendering still supports attributed/link text.
- Existing CSV/TSV wrap, column-width, and row-height controls still apply.
- Printing CSV/TSV and Markdown documents remains supported.
- No HTML/CSS/JavaScript renderer is introduced.

## Idempotence and Recovery

CSV/TSV parsing remains read-only and deterministic. If the lazy table viewport regresses embedded Markdown tables, the rollback is to gate the new renderer strictly on `tabularPresentation != nil`, which only applies to standalone CSV/TSV documents.

## Artifacts and Notes

No generated artifacts are expected. Runtime build/test outputs remain under `artifacts/` or the selected Xcode derived-data path.

## Interfaces and Dependencies

- No network dependency.
- No database or migration work.
- Uses SwiftUI-native lazy containers and the existing table controls.
