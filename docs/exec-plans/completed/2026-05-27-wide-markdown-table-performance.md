# Wide Markdown Table Performance

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

Dragging `tmp/ai-news-2026-05-13_to_2026-05-26.md` into the macOS app should open the parent `tmp` workspace, select the file, and render it without beachballing. The file is small, but it contains a Markdown table with long paragraph-like cells; the renderer needs to avoid expensive unconstrained SwiftUI table layout for that shape too.

## Progress

- [x] (2026-05-27T08:55Z) Confirmed the AI news file is about 6.3 KB and 26 lines, so this is not a raw file-size issue.
- [x] (2026-05-27T08:55Z) Confirmed the file is dominated by a 4-column Markdown table whose Digest cells are roughly 400-500 characters each.
- [x] (2026-05-27T09:02Z) Reproduced the current behavior with the checkpoint harness; the app built and launched but did not write `state.json`.
- [x] (2026-05-27T09:04Z) Added a wide-table policy alongside the existing large-row/cell table policy.
- [x] (2026-05-27T09:04Z) Added focused tests for small-wide and small-normal Markdown tables.
- [x] (2026-05-27T18:39Z) Added AppModel coverage that loads an AI-news-shaped table through the selected-file path and verifies the lazy plain-text table policy.
- [x] (2026-05-27T18:39Z) Focused table tests, the full unit wrapper, whitespace validation, and the macOS build pass.
- [x] (2026-05-27T18:39Z) Confirmed the macOS checkpoint failure is harness-wide in this worktree because `basic_typography.md` also fails before `state.json` export.

## Surprises & Discoveries

- Observation: the prior large-table fix only catches high row/cell counts.
  Evidence: `MarkdownTable.prefersLazyInteractiveViewport` currently checks row count and cell count thresholds, while this file has 10 rows and 44 cells.
- Observation: the current small-table path still uses an unconstrained SwiftUI `Grid` inside a horizontal `ScrollView`.
  Evidence: `ViewerShellView.tableContent(_:)` falls back to `Grid` when `shouldUseLazyTableViewport(for:)` is false.
- Observation: the checkpoint harness currently cannot serve as acceptance evidence for this fix.
  Evidence: both `tmp/ai-news-2026-05-13_to_2026-05-26.md` and the existing `basic_typography.md` fixture fail with missing `state.json`, while focused renderer/AppModel tests pass.

## Decision Log

- Decision: classify Markdown tables with very long cells as bounded-table candidates even when row count is small.
  Rationale: paragraph-like table cells can make natural table layout expensive and produce unusably wide tables; fixed-width cell layout is a better interactive default.
- Decision: set the long-cell threshold at 320 characters.
  Rationale: it catches the AI news digest table's 400-500 character cells while leaving ordinary short Markdown tables on the document-flow renderer.

## Outcomes & Retrospective

The renderer now classifies tables with very long cells as bounded lazy-viewport candidates even when they have few rows. Plain long-cell tables use the plain-text fast path so the AI-news-shaped Digest table avoids both the unconstrained `Grid` layout and unnecessary per-cell Markdown attribution. Small normal tables remain in document flow, and large tables with real inline Markdown keep attributed cells while still using the bounded viewport.

Validation passed through focused renderer/AppModel tests, the full unit wrapper, whitespace validation, and the macOS debug build. The macOS checkpoint harness could not be used as final evidence because it fails before state export for both this AI-news file and the unrelated `basic_typography.md` fixture in the same way.

## Context and Orientation

Relevant code:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/Models.swift` defines `MarkdownTable` and existing lazy viewport thresholds.
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift` chooses between bounded lazy table viewport and natural `Grid`.
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/MarkdownRenderer.swift` parses Markdown tables.
- `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift` contains Markdown table policy tests.

## Plan of Work

1. Capture the current AI news fixture through the macOS checkpoint harness.
2. Add a conservative long-cell threshold to `MarkdownTable`.
3. Ensure wide Markdown tables use the bounded lazy viewport and plain text fast path when possible.
4. Add tests for a small table with very long cells and a small normal table.
5. Re-run the AI news checkpoint, focused tests, full unit wrapper, docs checks, whitespace validation, and macOS build.

## Concrete Steps

From `/Users/matthewmoore/Projects/free-markdown-viewer`:

1. Run `./scripts/capture-checkpoint --fixture ai-news-2026-05-13_to_2026-05-26.md --fixture-root tmp --platform-target macos --checkpoint ai-news-macos-before`.
2. Edit `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/Models.swift`.
3. Add focused tests in `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift`.
4. Run focused tests and the AI news checkpoint.
5. Run repository validation.

## Validation and Acceptance

Acceptance:

- `tmp/ai-news-2026-05-13_to_2026-05-26.md` opens through the selected-file `AppModel` path without using the natural table layout.
- The AI-news-shaped table renders through the bounded lazy viewport policy.
- Existing small Markdown tables still use the natural document-flow table unless they are wide enough to trigger the policy.
- Large-row Markdown table behavior from the previous fix remains intact, including the linked-cell preservation path.

## Idempotence and Recovery

The policy change is deterministic and local to Markdown table rendering. If fixed-width rendering is too aggressive, the long-cell threshold can be raised without reverting the drag/drop behavior or large-table fix.

## Artifacts and Notes

Expected validation commands:

- `./scripts/capture-checkpoint --fixture ai-news-2026-05-13_to_2026-05-26.md --fixture-root tmp --platform-target macos --checkpoint ai-news-macos`
- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-wide-table-tests -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMarkdownRendererMarksSmallWidePlainPipeTableForLazyViewport" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMarkdownRendererKeepsSmallNormalPipeTableInDocumentFlow" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMarkdownRendererMarksLargePlainPipeTableAsPlainText" test`
- `./scripts/test-unit`
- `python3 scripts/check_execplan.py`
- `python3 scripts/knowledge/check_docs.py`
- `git diff --check`
- `./scripts/build --platform macos`

Actual validation:

- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-wide-table-tests -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMarkdownRendererMarksSmallWidePlainPipeTableForLazyViewport" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMarkdownRendererKeepsSmallNormalPipeTableInDocumentFlow" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMarkdownRendererMarksLargePlainPipeTableAsPlainText" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMarkdownRendererPreservesLargePipeTableLinksWhenCellsContainMarkdown" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testAppModelLoadsSmallWideMarkdownTableThroughLazyPlainTextPath" test` passed.
- `./scripts/test-unit` passed.
- `git diff --check` passed.
- `./scripts/build --platform macos` passed.
- `open -n "artifacts/DerivedData/Build/Products/Debug/Quick Markdown Viewer.app" --args --fixture-root "/Users/matthewmoore/Projects/free-markdown-viewer/tmp" --open-file "ai-news-2026-05-13_to_2026-05-26.md" --ui-test-mode "1"` opened one window titled `tmp > ai-news-2026-05-13_to_2026-05-26.md`; a process sample showed the main thread idle in `NSApplication.run`.
- `./scripts/capture-checkpoint --fixture ai-news-2026-05-13_to_2026-05-26.md --fixture-root tmp --platform-target macos --checkpoint ai-news-macos-before` failed before state export.
- `./scripts/capture-checkpoint --fixture basic_typography.md --platform-target macos --checkpoint sanity-basic-wide-table` failed before state export in the same way.

## Interfaces and Dependencies

No new dependencies are required.
