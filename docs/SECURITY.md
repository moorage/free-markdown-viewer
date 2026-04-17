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
- shipped app code may fetch direct user-authored media URLs over `https://`; deterministic tests may also use `http://127.0.0.1` / `localhost`
- shipped app code may also fetch public `github.com` repository metadata plus `raw.githubusercontent.com` file payloads only when the user explicitly opens a GitHub workspace URL; fetched snapshots must be cached under the app-owned cache directory and never written into user-selected folders
- no broad filesystem writes outside explicit fixture/artifact paths
- command-bridge failures must be explicit
