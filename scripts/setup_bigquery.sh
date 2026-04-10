#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   PROJECT_ID=my-gcp-project DATASET=analytics REGION=US ./scripts/setup_bigquery.sh
#
# Prereqs:
# - gcloud auth application-default login
# - bq CLI installed

: "${PROJECT_ID:?PROJECT_ID is required}"
: "${DATASET:=analytics}"
: "${REGION:=US}"

CUSTOMERS_TABLE="${PROJECT_ID}:${DATASET}.customers_raw"
USAGE_TABLE="${PROJECT_ID}:${DATASET}.intuit_usage_raw"

echo "Creating dataset ${PROJECT_ID}:${DATASET} in ${REGION} (if missing)..."
bq --location="${REGION}" mk --dataset --description "Analytics KPI dataset" "${PROJECT_ID}:${DATASET}" || true

echo "Loading customers.csv into ${CUSTOMERS_TABLE}..."
bq load \
  --replace \
  --source_format=CSV \
  --skip_leading_rows=1 \
  "${CUSTOMERS_TABLE}" \
  ./customers.csv \
  customerid:INT64,signup_date:DATE,channel:STRING,first_subscription_date:DATE,cancel_date:DATE

echo "Loading intuit_usage.csv into ${USAGE_TABLE}..."
bq load \
  --replace \
  --source_format=CSV \
  --skip_leading_rows=1 \
  "${USAGE_TABLE}" \
  ./intuit_usage.csv \
  CUSTOMERID:INT64,action_type_id:INT64,total_usage:INT64

TMP_SQL="$(mktemp)"
sed \
  -e "s/{{PROJECT_ID}}/${PROJECT_ID}/g" \
  -e "s/{{DATASET}}/${DATASET}/g" \
  ./sql/kpi_views.sql > "${TMP_SQL}"
echo "Creating/refreshing KPI views..."
bq query --use_legacy_sql=false < "${TMP_SQL}"

TMP_VALIDATION_SQL="$(mktemp)"
sed \
  -e "s/{{PROJECT_ID}}/${PROJECT_ID}/g" \
  -e "s/{{DATASET}}/${DATASET}/g" \
  ./sql/validation_checks.sql > "${TMP_VALIDATION_SQL}"
echo "Running validation checks..."
bq query --use_legacy_sql=false < "${TMP_VALIDATION_SQL}"

echo "Done."
