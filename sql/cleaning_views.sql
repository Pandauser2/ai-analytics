-- Replace placeholders {{PROJECT_ID}} and {{DATASET}} before execution.
-- Cleaning layer: standardize keys/labels and add quality flags before KPI logic.

CREATE OR REPLACE VIEW `{{PROJECT_ID}}.{{DATASET}}.dim_customers_clean` AS
SELECT
  customerid,
  signup_date,
  -- Normalize channel labels for consistent reporting.
  CASE
    WHEN channel IS NULL OR TRIM(channel) = '' THEN 'Unknown'
    ELSE INITCAP(TRIM(channel))
  END AS channel,
  first_subscription_date,
  cancel_date,
  -- Quality flags to support QA and downstream filtering if needed.
  signup_date IS NULL AS dq_missing_signup_date,
  first_subscription_date IS NOT NULL
    AND signup_date IS NOT NULL
    AND first_subscription_date < signup_date AS dq_subscription_before_signup,
  cancel_date IS NOT NULL
    AND first_subscription_date IS NOT NULL
    AND cancel_date < first_subscription_date AS dq_cancel_before_subscription
FROM `{{PROJECT_ID}}.{{DATASET}}.customers_raw`;

CREATE OR REPLACE VIEW `{{PROJECT_ID}}.{{DATASET}}.fct_usage_clean` AS
SELECT
  CUSTOMERID AS customerid,
  action_type_id,
  -- Guard against negative usage values; keep nulls as null for QA visibility.
  CASE
    WHEN total_usage < 0 THEN 0
    ELSE total_usage
  END AS total_usage,
  total_usage IS NULL AS dq_missing_total_usage,
  total_usage < 0 AS dq_negative_total_usage
FROM `{{PROJECT_ID}}.{{DATASET}}.intuit_usage_raw`;
