# Metric Definition

## Purpose
This document defines the **canonical schema** for the raw datasets used by this project.

Important: the physical `customers.csv` header row may include long prefixed column names, but the **logical schema is exactly the 5 fields below**, in this order. This matches how the file is loaded into BigQuery in `scripts/setup_bigquery.sh`.

## Raw file: `customers.csv`

### Canonical columns (logical schema)
| Column | Type (loaded) | Definition | Notes |
|---|---|---|---|
| `customerid` | INT64 | Unique customer identifier. | Primary key at customer grain (1 row per customer). |
| `signup_date` | DATE | Date the customer signed up. | Acquisition cohort anchor date. |
| `channel` | STRING | Marketing acquisition channel. | Examples observed include `PPC`, `Direct`, `SEO`, `Sales`, `Other`. |
| `first_subscription_date` | DATE | First subscription date for the customer. | Used as the conversion milestone in KPI logic. |
| `cancel_date` | DATE | Cancellation date for the customer. | May be empty/null if not canceled. |

### BigQuery table after load: `customers_raw`
`customers.csv` is loaded into `customers_raw` using the canonical column names above (see `scripts/setup_bigquery.sh`).

**Not present in this raw customer file (do not assume):** `Product_Name`, `First_Activation_Date`, `First_Purchase_Date`.

## Raw file: `intuit_usage.csv`

### Canonical columns (logical schema)
| Column | Type (loaded) | Definition | Notes |
|---|---|---|---|
| `CUSTOMERID` | INT64 | Customer identifier. | Join key to `customers_raw.customerid`. |
| `action_type_id` | INT64 | Encoded action/feature identifier. | Requires a business mapping table for human-readable labels. |
| `total_usage` | INT64 | Total usage count for that customer and action type. | This file is **aggregated** (no per-day grain in the header). |

### BigQuery table after load: `intuit_usage_raw`
`intuit_usage.csv` is loaded into `intuit_usage_raw` using the same canonical column names above (see `scripts/setup_bigquery.sh`).

**Not present in this raw usage file (do not assume):** `Product_name`, `Event_Date`, `Usage_count`.

## Modeled views (downstream of raw)
These are created by SQL in this repo and are the preferred reporting inputs:
- Cleaning/standardization: `dim_customers_clean`, `fct_usage_clean` (`sql/cleaning_views.sql`)
- KPIs: `kpi_*` views (`sql/kpi_views.sql`)

## Business and Reporting Guidance
- Clearly state any business assumptions in analysis outputs.
- Audience includes technical and non-technical stakeholders (marketers, PMs).
- Prioritize business insights and decisions over low-level implementation detail.

## Data Availability Note
- If a listed field is missing in the actual loaded table schema, do not infer values.
- Stop and request clarification or the correct source schema before continuing analysis.