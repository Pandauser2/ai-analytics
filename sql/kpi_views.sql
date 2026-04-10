-- Replace placeholders {{PROJECT_ID}} and {{DATASET}} before execution.

CREATE OR REPLACE VIEW `{{PROJECT_ID}}.{{DATASET}}.dim_customers_clean` AS
SELECT
  customerid,
  signup_date,
  channel,
  first_subscription_date,
  cancel_date
FROM `{{PROJECT_ID}}.{{DATASET}}.customers_raw`;

CREATE OR REPLACE VIEW `{{PROJECT_ID}}.{{DATASET}}.fct_usage_clean` AS
SELECT
  CUSTOMERID AS customerid,
  action_type_id,
  total_usage
FROM `{{PROJECT_ID}}.{{DATASET}}.intuit_usage_raw`;

CREATE OR REPLACE VIEW `{{PROJECT_ID}}.{{DATASET}}.kpi_signup_channel` AS
SELECT
  channel,
  COUNT(DISTINCT customerid) AS new_signups,
  SAFE_DIVIDE(COUNT(DISTINCT customerid), SUM(COUNT(DISTINCT customerid)) OVER ()) AS signup_share
FROM `{{PROJECT_ID}}.{{DATASET}}.dim_customers_clean`
GROUP BY channel;

CREATE OR REPLACE VIEW `{{PROJECT_ID}}.{{DATASET}}.kpi_conversion` AS
SELECT
  COUNT(DISTINCT customerid) AS total_signups,
  COUNT(DISTINCT IF(first_subscription_date IS NOT NULL, customerid, NULL)) AS converted_customers,
  SAFE_DIVIDE(
    COUNT(DISTINCT IF(first_subscription_date IS NOT NULL, customerid, NULL)),
    COUNT(DISTINCT customerid)
  ) AS trial_to_paid_conversion_rate,
  APPROX_QUANTILES(
    DATE_DIFF(first_subscription_date, signup_date, DAY), 100
  )[OFFSET(50)] AS median_days_to_convert
FROM `{{PROJECT_ID}}.{{DATASET}}.dim_customers_clean`;

CREATE OR REPLACE VIEW `{{PROJECT_ID}}.{{DATASET}}.kpi_churn` AS
SELECT
  COUNT(DISTINCT IF(first_subscription_date IS NOT NULL, customerid, NULL)) AS total_subscribers,
  COUNT(DISTINCT IF(cancel_date IS NOT NULL, customerid, NULL)) AS churned_customers,
  SAFE_DIVIDE(
    COUNT(DISTINCT IF(cancel_date IS NOT NULL, customerid, NULL)),
    COUNT(DISTINCT IF(first_subscription_date IS NOT NULL, customerid, NULL))
  ) AS churn_rate,
  COUNT(DISTINCT IF(
    cancel_date IS NOT NULL
    AND first_subscription_date IS NOT NULL
    AND DATE_DIFF(cancel_date, first_subscription_date, DAY) <= 30,
    customerid, NULL
  )) AS early_churn_customers,
  SAFE_DIVIDE(
    COUNT(DISTINCT IF(
      cancel_date IS NOT NULL
      AND first_subscription_date IS NOT NULL
      AND DATE_DIFF(cancel_date, first_subscription_date, DAY) <= 30,
      customerid, NULL
    )),
    COUNT(DISTINCT IF(first_subscription_date IS NOT NULL, customerid, NULL))
  ) AS early_churn_rate,
  COUNT(DISTINCT IF(first_subscription_date IS NOT NULL, customerid, NULL))
  - COUNT(DISTINCT IF(cancel_date IS NOT NULL, customerid, NULL)) AS net_subscriber_growth
FROM `{{PROJECT_ID}}.{{DATASET}}.dim_customers_clean`;

CREATE OR REPLACE VIEW `{{PROJECT_ID}}.{{DATASET}}.kpi_engagement_summary` AS
WITH joined AS (
  SELECT
    c.customerid,
    u.action_type_id,
    u.total_usage
  FROM `{{PROJECT_ID}}.{{DATASET}}.dim_customers_clean` c
  LEFT JOIN `{{PROJECT_ID}}.{{DATASET}}.fct_usage_clean` u
    ON c.customerid = u.customerid
)
SELECT
  COUNT(DISTINCT IF(total_usage > 0, customerid, NULL)) AS active_users,
  COUNT(DISTINCT customerid) AS total_customers,
  SAFE_DIVIDE(
    COUNT(DISTINCT IF(total_usage > 0, customerid, NULL)),
    COUNT(DISTINCT customerid)
  ) AS active_usage_penetration,
  AVG(IF(total_usage > 0, total_usage, NULL)) AS avg_usage_per_active_user
FROM joined;

CREATE OR REPLACE VIEW `{{PROJECT_ID}}.{{DATASET}}.kpi_feature_adoption` AS
WITH base AS (
  SELECT
    customerid,
    action_type_id,
    total_usage
  FROM `{{PROJECT_ID}}.{{DATASET}}.fct_usage_clean`
),
denom AS (
  SELECT COUNT(DISTINCT customerid) AS total_customers
  FROM `{{PROJECT_ID}}.{{DATASET}}.dim_customers_clean`
)
SELECT
  b.action_type_id,
  COUNT(DISTINCT IF(b.total_usage > 0, b.customerid, NULL)) AS adopting_customers,
  d.total_customers,
  SAFE_DIVIDE(COUNT(DISTINCT IF(b.total_usage > 0, b.customerid, NULL)), d.total_customers) AS feature_adoption_rate
FROM base b
CROSS JOIN denom d
GROUP BY b.action_type_id, d.total_customers;

CREATE OR REPLACE VIEW `{{PROJECT_ID}}.{{DATASET}}.kpi_power_users` AS
WITH user_usage AS (
  SELECT
    customerid,
    SUM(total_usage) AS total_usage_sum
  FROM `{{PROJECT_ID}}.{{DATASET}}.fct_usage_clean`
  GROUP BY customerid
),
threshold AS (
  SELECT APPROX_QUANTILES(total_usage_sum, 100)[OFFSET(75)] AS p75_usage
  FROM user_usage
)
SELECT
  t.p75_usage,
  COUNT(DISTINCT IF(u.total_usage_sum >= t.p75_usage, u.customerid, NULL)) AS power_users,
  COUNT(DISTINCT u.customerid) AS active_usage_customers,
  SAFE_DIVIDE(
    COUNT(DISTINCT IF(u.total_usage_sum >= t.p75_usage, u.customerid, NULL)),
    COUNT(DISTINCT u.customerid)
  ) AS power_user_rate
FROM user_usage u
CROSS JOIN threshold t
GROUP BY t.p75_usage;
