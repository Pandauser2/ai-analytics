-- Replace placeholders {{PROJECT_ID}} and {{DATASET}} before execution.
-- Validation Block: row counts, null checks, join integrity, reconciliation.

-- 1) Row counts
SELECT
  'row_counts' AS check_type,
  (SELECT COUNT(*) FROM `{{PROJECT_ID}}.{{DATASET}}.customers_raw`) AS customers_raw_rows,
  (SELECT COUNT(*) FROM `{{PROJECT_ID}}.{{DATASET}}.intuit_usage_raw`) AS usage_raw_rows;

-- 2) Null checks (critical keys and dates)
SELECT
  'null_checks_customers' AS check_type,
  COUNT(*) AS total_rows,
  COUNTIF(customerid IS NULL) AS null_customerid,
  COUNTIF(signup_date IS NULL) AS null_signup_date,
  COUNTIF(channel IS NULL) AS null_channel
FROM `{{PROJECT_ID}}.{{DATASET}}.customers_raw`;

SELECT
  'null_checks_usage' AS check_type,
  COUNT(*) AS total_rows,
  COUNTIF(CUSTOMERID IS NULL) AS null_customerid,
  COUNTIF(action_type_id IS NULL) AS null_action_type_id,
  COUNTIF(total_usage IS NULL) AS null_total_usage
FROM `{{PROJECT_ID}}.{{DATASET}}.intuit_usage_raw`;

-- 3) Join integrity (unmatched and potential duplicate inflation)
WITH usage_keys AS (
  SELECT DISTINCT CUSTOMERID AS customerid
  FROM `{{PROJECT_ID}}.{{DATASET}}.intuit_usage_raw`
),
customers_keys AS (
  SELECT DISTINCT customerid
  FROM `{{PROJECT_ID}}.{{DATASET}}.customers_raw`
),
usage_join AS (
  SELECT
    u.customerid,
    c.customerid IS NOT NULL AS matched_customer
  FROM usage_keys u
  LEFT JOIN customers_keys c
    ON u.customerid = c.customerid
)
SELECT
  'join_integrity' AS check_type,
  COUNT(*) AS distinct_usage_keys,
  COUNTIF(matched_customer) AS matched_usage_keys,
  COUNTIF(NOT matched_customer) AS unmatched_usage_keys,
  SAFE_DIVIDE(COUNTIF(NOT matched_customer), COUNT(*)) AS unmatched_usage_key_rate
FROM usage_join;

-- 4) Metric reconciliation (channel shares should sum to ~1)
WITH channel_share AS (
  SELECT
    SAFE_DIVIDE(COUNT(DISTINCT customerid), SUM(COUNT(DISTINCT customerid)) OVER ()) AS signup_share
  FROM `{{PROJECT_ID}}.{{DATASET}}.customers_raw`
  GROUP BY channel
)
SELECT
  'reconciliation_channel_share' AS check_type,
  SUM(signup_share) AS signup_share_sum,
  ABS(1 - SUM(signup_share)) AS abs_delta_from_1
FROM channel_share;
