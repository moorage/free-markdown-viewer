# RELIABILITY.md

This document defines reliability expectations, smoke paths, and operational invariants for the repository.

## Reliability goals

- predictable bootstrap from shell
- bounded failure modes
- deterministic artifacts for smoke checkpoints
- clear errors when simulator or Xcode prerequisites are missing

## Default smoke commands

- bootstrap: `./scripts/bootstrap-apple`
- build: `./scripts/build --platform all`
- unit tests: `./scripts/test-unit`
- macOS smoke: `./scripts/test-ui-macos --smoke`
- iOS/iPad smoke: `./scripts/test-ui-ios --device both --smoke`
- fast loop: `./scripts/agent-loop`

If a smoke path cannot run because Xcode platform components are missing, the command should fail clearly and say what is missing.
