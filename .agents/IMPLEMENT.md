# Implementation loop

Use this file as the execution runbook once an ExecPlan exists.

## Execution rules

1. Treat the active ExecPlan as the source of truth.
2. Work one milestone at a time.
3. Keep diffs scoped to the current milestone.
4. Run the milestone's validation commands before moving on.
5. If validation fails, fix the issue before starting the next milestone.
6. Update the ExecPlan's `Progress`, `Decision Log`, and `Surprises & Discoveries` after each meaningful change.
7. Update `.agents/DOCUMENTATION.md` after each milestone with what changed, what was validated, and what remains.
8. Prefer additive, reversible changes when risk is high.
9. If the plan changes materially, update the plan before or while changing the code, not after.
