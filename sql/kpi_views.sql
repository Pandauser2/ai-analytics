-- Replace placeholders {{PROJECT_ID}} and {{DATASET}} before execution.
-- Timezone assumption: all dates/timestamps are interpreted as UTC.
-- Important modeling note:
-- - Current usage source is aggregated (`total_usage`) and has no event timestamp.
-- - KPIs in this file are snapshot-style, not true time-window WAU/MAU/cohort metrics.
-- - If event-level usage is added later, revisit KPI logic for period filtering.

-- NOTE: dim_customers_clean and fct_usage_clean are created in sql/cleaning_views.sql.
-- This file assumes cleaning views already exist.

-- Acquisition mix by channel.
-- Assumption: channel values are already normalized (e.g., PPC/SEO/Direct/Sales).
CREATE OR REPLACE VIEW `{{PROJECT_ID}}.{{DATASET}}.kpi_signup_channel` AS
SELECT
  channel,
  COUNT(DISTINCT customerid) AS new_signups,
  SAFE_DIVIDE(COUNT(DISTINCT customerid), SUM(COUNT(DISTINCT customerid)) OVER ()) AS signup_share
FROM `{{PROJECT_ID}}.{{DATASET}}.dim_customers_clean`
GROUP BY channel;

-- Conversion summary.
-- Assumption: first_subscription_date indicates conversion from trial/free to paid.
-- Caveat: median_days_to_convert may be 0 when same-day conversion is common.
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
FROM `{{PROJECT_ID}}.{{DATASET}}.dim_customers_clean`
WHERE NOT dq_subscription_before_signup;

-- Churn summary.
-- Assumptions:
-- - Subscriber base is customers with non-null first_subscription_date.
-- - Churned customers are those with non-null cancel_date.
-- - Early churn window is defined as <= 30 days from first subscription.
-- Caveat: this is a global snapshot metric, not period-window churn.
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
FROM `{{PROJECT_ID}}.{{DATASET}}.dim_customers_clean`
WHERE NOT dq_subscription_before_signup
  AND NOT dq_cancel_before_subscription;

-- Engagement summary across all customers.
-- Assumption: active user is customer with total_usage > 0 in the aggregated usage source.
CREATE OR REPLACE VIEW `{{PROJECT_ID}}.{{DATASET}}.kpi_engagement_summary` AS
WITH joined AS (
  SELECT
    c.customerid,
    u.action_type_id,
    u.total_usage
  FROM `{{PROJECT_ID}}.{{DATASET}}.dim_customers_clean` c
  LEFT JOIN `{{PROJECT_ID}}.{{DATASET}}.fct_usage_clean` u
    ON c.customerid = u.customerid
  WHERE NOT c.dq_subscription_before_signup
    AND NOT c.dq_cancel_before_subscription
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

-- Feature adoption by action_type_id.
-- Assumption: denominator is total distinct customers in dim_customers_clean.
-- Caveat: action_type_id should be mapped to business-friendly feature names in BI.
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
  WHERE NOT dq_subscription_before_signup
    AND NOT dq_cancel_before_subscription
)
SELECT
  b.action_type_id,
  COUNT(DISTINCT IF(b.total_usage > 0, b.customerid, NULL)) AS adopting_customers,
  d.total_customers,
  SAFE_DIVIDE(COUNT(DISTINCT IF(b.total_usage > 0, b.customerid, NULL)), d.total_customers) AS feature_adoption_rate
FROM base b
CROSS JOIN denom d
JOIN `{{PROJECT_ID}}.{{DATASET}}.dim_customers_clean` c
  ON b.customerid = c.customerid
WHERE NOT c.dq_subscription_before_signup
  AND NOT c.dq_cancel_before_subscription
GROUP BY b.action_type_id, d.total_customers;

-- Power-user summary based on distribution threshold.
-- Assumption: power users are customers above or equal to p75 of summed usage.
-- Caveat: p75 threshold is data-dependent and should be reviewed periodically.
CREATE OR REPLACE VIEW `{{PROJECT_ID}}.{{DATASET}}.kpi_power_users` AS
WITH user_usage AS (
  SELECT
    u.customerid,
    SUM(u.total_usage) AS total_usage_sum
  FROM `{{PROJECT_ID}}.{{DATASET}}.fct_usage_clean` u
  JOIN `{{PROJECT_ID}}.{{DATASET}}.dim_customers_clean` c
    ON u.customerid = c.customerid
  WHERE NOT c.dq_subscription_before_signup
    AND NOT c.dq_cancel_before_subscription
  GROUP BY u.customerid
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

-- North Star (Streamlit / ad-hoc): one row per subscriber with core-action flags.
-- Reuses dim_customers_clean + fct_usage_clean; aligns DQ filters with kpi_churn / kpi_feature_adoption.
-- Core actions 1 and 3 are fixed here; if product changes, update this view and the app constant.
CREATE OR REPLACE VIEW `{{PROJECT_ID}}.{{DATASET}}.kpi_north_star_subscriber_detail` AS
WITH usage_core AS (
  SELECT
    customerid,
    SUM(IF(action_type_id = 1, total_usage, 0)) AS usage_action_1,
    SUM(IF(action_type_id = 3, total_usage, 0)) AS usage_action_3
  FROM `{{PROJECT_ID}}.{{DATASET}}.fct_usage_clean`
  GROUP BY customerid
)
SELECT
  c.customerid,
  c.channel,
  c.cancel_date IS NOT NULL AS has_cancel_date,
  COALESCE(u.usage_action_1, 0) > 0 AS adopted_action_1,
  COALESCE(u.usage_action_3, 0) > 0 AS adopted_action_3,
  (COALESCE(u.usage_action_1, 0) > 0 AND COALESCE(u.usage_action_3, 0) > 0) AS north_star_both_core
FROM `{{PROJECT_ID}}.{{DATASET}}.dim_customers_clean` c
LEFT JOIN usage_core u
  ON c.customerid = u.customerid
WHERE c.first_subscription_date IS NOT NULL
  AND NOT c.dq_subscription_before_signup
  AND NOT c.dq_cancel_before_subscription;
