# BigQuery + Looker Studio Setup (Analytics)

This setup loads local CSV data into BigQuery, creates KPI views, and runs a validation block for data quality.

## Project Docs
- Analysis plan and metric dictionary: `ANALYSIS_PLAN.md`
- Canonical raw schema: `schema_definition.md`
- Latest validation run status: `VALIDATION_RESULTS.md`

## Streamlit North Star dashboard (BigQuery)
The app reads the curated view **`kpi_north_star_subscriber_detail`** (see `sql/kpi_views.sql`) built from **`dim_customers_clean`** + **`fct_usage_clean`**. Run `./scripts/setup_bigquery.sh` first so views exist.

North Star definition (aligned with the view):

- **Subscriber** = `first_subscription_date` present, with cleaning DQ flags applied in the view
- **Core actions** = `action_type_id` in `{1, 3}`
- **North Star** = share of subscribers with **both** core actions adopted (`total_usage > 0` in the cleaned fact table)

**Config:** set `PROJECT_ID` and `DATASET` in the environment (same as the BigQuery setup script), or copy `.streamlit/secrets.toml.example` to `.streamlit/secrets.toml` and set `BIGQUERY_PROJECT` / `BIGQUERY_DATASET`. You can **leave the sidebar project id blank** if `GOOGLE_CLOUD_PROJECT` is set or gcloud has a default project (`gcloud config set project …`).

**Authentication (ADC):** the app uses **Application Default Credentials**, not passwords in code. On your laptop, run **`gcloud auth application-default login`** once (see [Set up ADC](https://cloud.google.com/docs/authentication/external/set-up-adc)). If Streamlit shows “default credentials were not found”, that command was never run for your user, or Streamlit is using a different OS user / environment. For production, use a **service account** and set **`GOOGLE_APPLICATION_CREDENTIALS`** to the JSON key path. The identity needs BigQuery **job create** and **data read** on the project.

Install and run:

```bash
cd /Users/rajeshmukherjee/Desktop/04_Data_Science/Projects/Cursor_test_project/Analytics
python3 -m pip install -r requirements.txt
python3 -m streamlit run streamlit_north_star_app.py
```

Use **`python3 -m streamlit run …`** (not a bare `streamlit` on `PATH`) so Streamlit uses the same interpreter where you ran `pip install`. Alternatively run **`./scripts/run_streamlit_north_star.sh`**, which installs deps then starts Streamlit with `python3 -m streamlit`.

If you see **`ImportError: cannot import name 'bigquery' from 'google.cloud'`** or the in-app “Missing the BigQuery client library” message, install into the interpreter shown in the error (`… -m pip install google-cloud-bigquery`). Cursor/IDE “Run Streamlit” buttons sometimes use a different Python than your terminal.

Use the sidebar **Channel filter** to slice the subscriber universe. Charts use **Plotly**; tables/metrics use **pandas**.

## Files
- `scripts/setup_bigquery.sh` - one-command setup and refresh
- `sql/cleaning_views.sql` - data cleaning/standardization views
- `sql/kpi_views.sql` - KPI views built on cleaned views
- `sql/validation_checks.sql` - validation block queries
- `streamlit_north_star_app.py` - Streamlit North Star dashboard (BigQuery + Plotly)
- `scripts/run_streamlit_north_star.sh` - install deps + run app with `python3 -m streamlit`
- `requirements.txt` - Python deps for Streamlit app

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
