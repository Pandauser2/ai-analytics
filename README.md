# BigQuery + Looker Studio Setup (Analytics)

This setup loads local CSV data into BigQuery, creates KPI views, and runs a validation block for data quality.

## Project Docs
- Analysis plan and metric dictionary: `ANALYSIS_PLAN.md`
- Latest validation run status: `VALIDATION_RESULTS.md`
- Looker setup and operations checklist: `LOOKER_EXECUTION_CHECKLIST.md`

## Files
- `scripts/setup_bigquery.sh` - one-command setup and refresh
- `sql/cleaning_views.sql` - data cleaning/standardization views
- `sql/kpi_views.sql` - KPI views built on cleaned views
- `sql/validation_checks.sql` - validation block queries

## Setup Requirements
1. **Google Cloud project** (example: `awesome-project-1-353706`)
2. **BigQuery API enabled** in that project
3. **Google Cloud CLI installed** (`gcloud`, `bq`)
4. **Authenticated CLI session**
   - `gcloud auth login`
   - `gcloud auth application-default login`

Verify installation:

```bash
gcloud --version
bq version
```

If `bq` is missing, install/update Cloud SDK and restart terminal:

```bash
brew install --cask google-cloud-sdk
gcloud components install bq
```

Then initialize your shell for gcloud if prompted:

```bash
gcloud init
```

## BigQuery Dataset Name (what to use)
- A dataset is like a folder inside your BigQuery project.
- In this setup, you can use: `DATASET="analytics"`.
- If it does not exist, the script creates it automatically.
- Full target path format is: `PROJECT_ID:DATASET`  
  Example: `awesome-project-1-353706:analytics`

## Setup and Run Steps
Run from the `Analytics/` directory.

```bash
# 1) Make script executable (run once)
chmod +x ./scripts/setup_bigquery.sh

# 2) Run setup/load/views/validation
PROJECT_ID="your-gcp-project-id" DATASET="analytics" REGION="US" ./scripts/setup_bigquery.sh
```

This will:
1. Create dataset (if missing)
2. Load:
   - `customers.csv` -> `customers_raw`
   - `intuit_usage.csv` -> `intuit_usage_raw`
3. Create cleaning views:
   - `dim_customers_clean`
   - `fct_usage_clean`
4. Create KPI views:
   - `kpi_signup_channel`
   - `kpi_conversion`
   - `kpi_churn`
   - `kpi_engagement_summary`
   - `kpi_feature_adoption`
   - `kpi_power_users`
5. Run Validation Block:
   - Row counts
   - Null checks
   - Join integrity
   - Reconciliation check (signup share sum)

## Common Errors and Fixes

### Error: `chmod: PROJECT_ID=... No such file or directory`
Cause: `chmod` and environment variables were typed in one command.

Use two separate commands:

```bash
chmod +x ./scripts/setup_bigquery.sh
PROJECT_ID="awesome-project-1-353706" DATASET="analytics" REGION="US" ./scripts/setup_bigquery.sh
```

### Error: `bq: command not found`
Cause: BigQuery CLI is not installed or not on PATH.

Fix:
1. Install Cloud SDK and `bq`
2. Restart terminal
3. Re-run:

```bash
bq version
PROJECT_ID="awesome-project-1-353706" DATASET="analytics" REGION="US" ./scripts/setup_bigquery.sh
```

## Connect Looker Studio
1. Open [Looker Studio](https://lookerstudio.google.com/)
2. Create report -> Add data -> BigQuery
3. Select your project and dataset
4. Add KPI views as data sources
5. Recommended pages:
   - Executive KPI Summary
   - Acquisition & Conversion
   - Churn
   - Engagement / Feature Adoption

## Notes and Known Limits
- Usage data has no event timestamp column, so true WAU/MAU trend and classical cohort retention are not available yet.
- Product-level segmentation is not available with current columns.
