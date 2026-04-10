---
name: analysis-plan
description: Document analytics analysis plans with metric definitions, source tables/columns, validation checks, and iteration steps. Use when the user asks for an analysis plan, dashboard planning, KPI mapping, or refinement/next-step guidance.
---

# Analysis Plan

## When to Use
Use this skill when the user asks to:
- create an analysis plan,
- define metrics and formulas,
- map metrics to tables/columns,
- document validation checks,
- describe how to iterate/refine and define next steps.

## Workflow (Vibe Analysis Protocol)
Follow this order:
1. **Plan**
2. **Refine**
3. **Execute**
4. **Validate**

Do not skip Validate.

## Required Inputs
Before drafting, confirm:
- business goal / north star metric,
- available tables and exact columns,
- data grain and time coverage,
- tool constraints (SQL dialect, BI tool),
- timezone (default UTC unless user says otherwise).

If a required table/column is missing, stop and ask. Never invent schema.

## Output Template
Use this structure:

```markdown
# Analysis Plan: <title>

## 1) Objective
- Business question:
- North star / success metric:
- Decision this analysis will support:

## 2) Available Data
| Table | Grain | Key columns | Notes |
|---|---|---|---|

## 3) Metric Dictionary
| Metric | Business definition | Formula | Table(s) | Column(s) | Grain | Caveats |
|---|---|---|---|---|---|---|

## 4) Analysis Plan (Plan -> Refine -> Execute -> Validate)
- Plan:
- Refine:
- Execute:
- Validate:

## 5) Validation Block
| Check | Logic | Pass criteria | Status |
|---|---|---|---|

## 6) Iteration and Refinement
- What to review with stakeholders:
- Sensitivity checks:
- Definition changes to track:
- Versioning notes:

## 7) Next Steps
- Immediate:
- This week:
- Future enhancements:
```

## Validation Block Rules (Mandatory)
Always include checks for:
1. **Row counts** (raw vs filtered vs final model)
2. **Null checks** (keys, dates, metric-driving fields)
3. **Join integrity** (key uniqueness, unmatched keys, duplicate inflation)
4. **Metric reconciliation** (totals and shares)
5. **Range sanity** (rates in [0,1], no impossible negatives unless allowed)

If any critical check fails:
- mark status as **FAIL**,
- identify impact,
- provide fix and rerun step.

## Iteration and Refinement Rules
- Start with a minimal KPI set that can be derived from existing columns.
- Split metrics into:
  - **Derivable now**
  - **Blocked by missing data**
- For blocked metrics, list exact missing columns/tables.
- After each stakeholder review:
  - capture changed definitions,
  - update formulas,
  - rerun validation,
  - log version/date.

## Next Steps Guidance
Recommend next steps in three horizons:
- **Immediate (today):** validation, baseline dashboard, obvious data issues
- **Short-term (this week):** segmentation, cut-by-channel, trend pages
- **Medium-term:** missing events/tables, better retention/cohorts, automation

## Quality Checklist
Before finalizing, verify:
- [ ] Every metric maps to explicit tables and columns
- [ ] No guessed schema or assumptions without labeling
- [ ] Validation Block is complete with pass/fail
- [ ] Blocked metrics list exact missing data
- [ ] Next steps are actionable and time-scoped
