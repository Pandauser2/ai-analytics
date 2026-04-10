# Validation Results

## Run Metadata
- Validation command: `bq query --use_legacy_sql=false < validation_checks_run.sql`
- Working directory: `Analytics/`
- BigQuery project/dataset: `awesome-project-1-353706.analytics`
- Final validation status: **PASS**

## Check Outcomes (Latest Run)

| Check | Status | Result |
|---|---|---|
| Row counts | **PASS** | `customers_raw_rows=10000`, `usage_raw_rows=43630` |
| Null checks (customers) | **PASS** | `null_customerid=0`, `null_signup_date=0`, `null_channel=0` |
| Null checks (usage) | **PASS** | `null_customerid=0`, `null_action_type_id=0`, `null_total_usage=0` |
| Join integrity | **PASS** | `distinct_usage_keys=9918`, `matched_usage_keys=9918`, `unmatched_usage_keys=0`, `unmatched_usage_key_rate=0.0` |
| Reconciliation (channel share sum) | **PASS** | `signup_share_sum=1.0`, `abs_delta_from_1=0.0` |

## KPI Sanity Checks (Plausibility)

### Range Checks
| View | Status | Result |
|---|---|---|
| `kpi_signup_channel` | **PASS** | `row_count=5`, `min_rate=0.0584`, `max_rate=0.3478`, `out_of_range_rates=0` |
| `kpi_conversion` | **PASS** | `row_count=1`, `rate=0.5911`, `out_of_range_rates=0` |
| `kpi_churn` | **PASS** | `row_count=1`, `churn_rate=0.241245`, `early_churn_rate=0.077313`, `out_of_range_rates=0` |
| `kpi_engagement_summary` | **PASS** | `row_count=1`, `active_usage_penetration=0.9918`, `out_of_range_rates=0` |
| `kpi_feature_adoption` | **PASS** | `row_count=7`, `min_rate=0.4097`, `max_rate=0.9366`, `out_of_range_rates=0` |
| `kpi_power_users` | **PASS** | `row_count=1`, `power_user_rate=0.250655`, `out_of_range_rates=0` |

### Headline KPI Values
- Conversion: `5911 / 10000 = 0.5911`
- Churn: `1426 / 5911 = 0.241245`
- Early churn: `457 / 5911 = 0.077313`
- Net subscriber growth: `4485`
- Active users: `9918 / 10000 = 0.9918`
- Average usage per active user: `47.9305`
- Power users: `2486 / 9918 = 0.250655` (threshold `p75_usage=130`)

## Operational Note
- Keep this file updated after each production refresh run.
