# Running implementation notes

- active ExecPlans:
  - `docs/exec-plans/active/2026-03-19-swift-codex-cli-harness.md`
- current milestone:
  - bootstrap implementation not started yet
- commands run:
  - none yet for implementation
- evidence gathered:
  - repository currently contains the generated Xcode scaffold plus early planning docs
- important discoveries:
  - the app scheme resolves through `xcodebuild`
  - the target is configured as a multiplatform template
  - the current Xcode installation reports only macOS destinations as eligible for the shared scheme
- open risks or blockers:
  - iOS destination support may require additional Xcode platform components before simulator verification can pass
