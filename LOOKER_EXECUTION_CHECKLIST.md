# Looker Execution Checklist

## Status Summary
- Step 1 (Validation SQL): **Completed**
- Step 2 (KPI sanity checks): **Completed**
- Step 3 (Connect Looker Studio): **Ready to execute in UI**
- Step 4 (Add report controls): **Ready to execute in UI**
- Step 5 (Refresh/Ops setup): **Defined**

## 3) Connect Looker Studio
1. Open [Looker Studio](https://lookerstudio.google.com/).
2. Create report -> Add data -> BigQuery.
3. Select project `awesome-project-1-353706` and dataset `analytics`.
4. Add these views as data sources:
   - `kpi_signup_channel`
   - `kpi_conversion`
   - `kpi_churn`
   - `kpi_engagement_summary`
   - `kpi_feature_adoption`
   - `kpi_power_users`
5. Build pages:
   - Executive Summary
   - Acquisition & Conversion
   - Churn
   - Engagement

## 4) Add Report Controls
- Date range control: apply where date dimensions exist (current KPI views are mostly snapshot views).
- Channel filter: use `channel` from `kpi_signup_channel`.
- `action_type_id` filter: use `action_type_id` from `kpi_feature_adoption`.

## 5) Refresh / Ops
### Recommended cadence
- **Daily at 07:00 UTC** for business-day reporting.

### Refresh command
```bash
PROJECT_ID="awesome-project-1-353706" DATASET="analytics" REGION="US" ./scripts/setup_bigquery.sh
```

### Runbook after each refresh
1. Confirm script exits successfully.
2. Run validation SQL (`sql/validation_checks.sql`) if not already run by script.
3. Update `VALIDATION_RESULTS.md` with latest pass/fail and key numbers.
4. In Looker Studio, confirm data source refresh and spot-check headline KPIs.
