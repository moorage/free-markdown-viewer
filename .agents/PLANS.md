# Codex Execution Plans (ExecPlans)

This document defines the required structure for ExecPlans in this repository. Treat the reader as a newcomer with only the working tree and the single plan file in front of them.

## Required sections

Every active ExecPlan must include these headings:

- `## Purpose / Big Picture`
- `## Progress`
- `## Surprises & Discoveries`
- `## Decision Log`
- `## Outcomes & Retrospective`
- `## Context and Orientation`
- `## Plan of Work`
- `## Concrete Steps`
- `## Validation and Acceptance`
- `## Idempotence and Recovery`
- `## Artifacts and Notes`
- `## Interfaces and Dependencies`

## Rules

- plans are living documents
- `Progress` must use timestamped checkboxes
- plans must be self-contained
- plans must describe working behavior, not just code edits
- all commands must be explicit and runnable from a defined working directory
- if the implementation diverges, update the plan before or while changing code

## Location

- active plans: `docs/exec-plans/active/`
- completed plans: `docs/exec-plans/completed/`

## Validation

Run:

```bash
python3 scripts/check_execplan.py
```

after editing any active plan.
