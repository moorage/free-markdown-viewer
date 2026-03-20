# ExecPlan Location Guide

This repository is in bootstrap mode. The durable Codex control plane described by the active harness plan does not exist yet, so this file is the temporary routing guide for ExecPlans until Milestone 1 adds `.agents/PLANS.md`.

## Source of truth

- bootstrap standard: `docs/exec-plans/active/2026-03-19-swift-codex-cli-harness.md`
- active plans: `docs/exec-plans/active/`
- completed plans: `docs/exec-plans/completed/`

When `.agents/PLANS.md` is added, make that file the authoritative ExecPlan authoring standard and update this file in the same change.

## Naming

Use `YYYY-MM-DD-short-kebab-name.md`.

New work should keep one active plan per major workstream.

## Working rules

- keep `Progress`, `Decision Log`, `Surprises & Discoveries`, and `Outcomes & Retrospective` current
- update the active plan before implementation diverges from it
- move finished plans into `docs/exec-plans/completed/`
- once the harness exists, add ExecPlan validation to the standard verification loop
