# SECURITY.md

This internal document covers repository-local security expectations.

## Trust boundaries

- fixture files are local inputs and must be treated as untrusted content
- launch arguments and file-backed harness commands are debug-only inputs and must not silently mutate unrelated files
- screenshot, state, and perf artifact writers must stay inside configured artifact directories

## Rules

- no `WKWebView`
- no remote code execution paths
- no network dependency in the core harness loop
- no broad filesystem writes outside explicit fixture/artifact paths
- command-bridge failures must be explicit
