# Analysis Plan: Intuit Active User Growth (Analytics)

## 1) Objective

- Business question: Which acquisition, conversion, churn, and engagement levers can grow the Intuit active user base?
- North star / success metric: Intuit Active Users (proxy based on available usage data).
- Decision this analysis will support: channel investment, onboarding priorities, and retention interventions.

## 2) Available Data

Canonical raw schema reference: `schema_definition.md`.

| Table                 | Grain                            | Key columns                                                                      | Notes                                                           |
| --------------------- | -------------------------------- | -------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| `customers_raw`       | 1 row per customer               | `customerid`, `signup_date`, `channel`, `first_subscription_date`, `cancel_date` | Source: `customers.csv`; supports acquisition/conversion/churn. |
| `intuit_usage_raw`    | customer x action_type aggregate | `CUSTOMERID`, `action_type_id`, `total_usage`                                    | Source: `intuit_usage.csv`; no event timestamp in current file. |
| `dim_customers_clean` | 1 row per customer               | `customerid`, `signup_date`, `channel`, `first_subscription_date`, `cancel_date` | Clean view from `customers_raw`.                                |
| `fct_usage_clean`     | customer x action_type aggregate | `customerid`, `action_type_id`, `total_usage`                                    | Clean view from `intuit_usage_raw`.                             |
## 3) Metric Dictionary
| Metric                        | Business definition                         | Formula                                                                                                                                                                        | Table(s)                                 | Column(s)                                              | Grain                                     | Caveats                                           |
| ----------------------------- | ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------- | ------------------------------------------------------ | ----------------------------------------- | ------------------------------------------------- |
| New signups                   | New acquired customers                      | `COUNT(DISTINCT customerid)`                                                                                                                                                   | `dim_customers_clean`                    | `customerid`                                           | Snapshot / period filter on `signup_date` | Period requires explicit filter in BI.            |
| Signup share by channel       | Acquisition mix by marketing source         | `COUNT(DISTINCT customerid) by channel / total distinct customers`                                                                                                             | `dim_customers_clean`                    | `customerid`, `channel`                                | Channel                                   | Already materialized in `kpi_signup_channel`.     |
| Trial-to-paid conversion rate | Share of signups that became subscribers    | `COUNT(DISTINCT IF(first_subscription_date IS NOT NULL, customerid, NULL)) / COUNT(DISTINCT customerid)`                                                                       | `dim_customers_clean`                    | `customerid`, `first_subscription_date`                | Snapshot                                  | Uses available subscription date only.            |
| Median days to convert        | Typical time from signup to paid            | `P50(DATE_DIFF(first_subscription_date, signup_date, DAY))`                                                                                                                    | `dim_customers_clean`                    | `signup_date`, `first_subscription_date`               | Snapshot                                  | Null for non-converters excluded.                 |
| Churn rate                    | Share of subscribers who canceled           | `COUNT(DISTINCT IF(cancel_date IS NOT NULL, customerid, NULL)) / COUNT(DISTINCT IF(first_subscription_date IS NOT NULL, customerid, NULL))`                                    | `dim_customers_clean`                    | `cancel_date`, `first_subscription_date`, `customerid` | Snapshot                                  | No explicit active period window in current view. |
| Early churn rate              | Cancel within 30 days of subscription       | `COUNT(DISTINCT IF(DATE_DIFF(cancel_date, first_subscription_date, DAY) <= 30, customerid, NULL)) / COUNT(DISTINCT IF(first_subscription_date IS NOT NULL, customerid, NULL))` | `dim_customers_clean`                    | `cancel_date`, `first_subscription_date`, `customerid` | Snapshot                                  | Includes only customers with both dates.          |
| Net subscriber growth         | Net adds from subscription and cancellation | `COUNT(DISTINCT IF(first_subscription_date IS NOT NULL, customerid, NULL)) - COUNT(DISTINCT IF(cancel_date IS NOT NULL, customerid, NULL))`                                    | `dim_customers_clean`                    | `first_subscription_date`, `cancel_date`, `customerid` | Snapshot                                  | Not time-bounded unless filtered.                 |
| Active usage penetration      | Customers with any usage                    | `COUNT(DISTINCT IF(total_usage > 0, customerid, NULL)) / COUNT(DISTINCT customerid)`                                                                                           | `dim_customers_clean`, `fct_usage_clean` | `customerid`, `total_usage`                            | Snapshot                                  | Usage is aggregated, not time-series.             |
| Avg usage per active user     | Average usage among active users            | `AVG(IF(total_usage > 0, total_usage, NULL))`                                                                                                                                  | `fct_usage_clean`                        | `total_usage`                                          | Snapshot                                  | Sensitive to outliers.                            |
| Feature adoption rate         | Share of customers using each action type   | `COUNT(DISTINCT IF(total_usage > 0, customerid, NULL)) by action_type_id / total customers`                                                                                    | `fct_usage_clean`, `dim_customers_clean` | `action_type_id`, `total_usage`, `customerid`          | Action type                               | Action labels need mapping from IDs.              |
| Power user rate               | Share of users above p75 usage threshold    | `COUNT(DISTINCT IF(total_usage_sum >= p75, customerid, NULL)) / COUNT(DISTINCT customerid)`                                                                                    | `fct_usage_clean`                        | `customerid`, `total_usage`                            | Snapshot                                  | Threshold based on current dataset distribution.  |
## 4) Analysis Plan (Plan -> Refine -> Execute -> Validate)

- Plan:
  - Align on north star interpretation with current data (active-user proxy).
  - Confirm KPI scope for v1 dashboard.
- Refine:
  - Run cleaning layer in `sql/cleaning_views.sql` to standardize channels and add data-quality flags.
  - Use cleaned views (`dim_customers_clean`, `fct_usage_clean`) as semantic layer.
  - Split KPIs into derivable-now vs blocked-by-missing-data.
- Execute:
  - Build KPI views in `sql/kpi_views.sql`.
  - Publish in BigQuery dataset `analytics`.
  - Connect Looker Studio to KPI views.
- Validate:
  - Run `sql/validation_checks.sql`.
  - Record outcomes in `VALIDATION_RESULTS.md`.
  - Mark PASS/FAIL and rerun if failed.

## 5) Validation Block
| Check                   | Logic                                                                                            | Pass criteria                                                    | Status                     |
| ----------------------- | ------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------- | -------------------------- |
| Row counts              | Compare row volume of `customers_raw` and `intuit_usage_raw` after load                          | Non-zero and consistent with source file expectations            | Pending latest run capture |
| Null checks (customers) | `COUNTIF(customerid IS NULL)`, `COUNTIF(signup_date IS NULL)`, `COUNTIF(channel IS NULL)`        | `customerid` should be 0 nulls; others within accepted tolerance | Pending latest run capture |
| Null checks (usage)     | `COUNTIF(CUSTOMERID IS NULL)`, `COUNTIF(action_type_id IS NULL)`, `COUNTIF(total_usage IS NULL)` | `CUSTOMERID` should be 0 nulls; metric columns within tolerance  | Pending latest run capture |
| Join integrity          | Distinct usage keys matched to customer keys; unmatched key rate                                 | Unmatched rate near 0 or understood/documented                   | Pending latest run capture |
| Reconciliation          | Sum of channel shares should be approximately 1.0                                                | `ABS(1 - SUM(signup_share)) < 0.001`                             | Pending latest run capture |
| Range sanity            | Rates in `[0,1]` for conversion/churn/adoption/power user                                        | No rate outside `[0,1]`                                          | Pending latest run capture |
## 6) Iteration and Refinement

- What to review with stakeholders:
  - Whether active-user proxy is acceptable without usage timestamps.
  - Which channels and feature actions need decision-ready cuts.
- Sensitivity checks:
  - Power-user threshold alternatives (p70/p75/p90).
  - Early churn window alternatives (15/30/45 days).
- Definition changes to track:
  - Any revision to conversion denominator.
  - Any revision to churn windowing logic.
- Versioning notes:
  - Log changes in SQL and validation outcome by run date in UTC.

## 7) Derivable vs Blocked Metrics

- Derivable now:
  - acquisition mix, conversion, days-to-convert, churn/early churn, net subscriber growth, usage penetration, feature adoption, power users.
- Blocked by missing data:
  - true WAU/MAU time trends (missing usage event date),
  - cohort retention curves (missing time-series activity),
  - product-level KPI cuts (missing explicit product column in current loaded schema).

## 8) Next Steps

- Immediate (today):
  - run validation checks and update `VALIDATION_RESULTS.md`,
  - create Looker Studio v1 pages using KPI views,
  - map `action_type_id` values to business-friendly labels.
- This week:
  - add dashboard filters and stakeholder review cadence,
  - add windowed trend views if date columns are added.
- Future enhancements:
  - ingest event-level usage with timestamps,
  - add product dimension and marketing spend for CAC/ROI,
  - automate refresh + validation notifications.

