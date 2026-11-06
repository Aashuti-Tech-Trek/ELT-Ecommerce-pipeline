#!/usr/bin/env bash
# One-time GCP setup for the Olist ETL pipeline.
# Creates: raw GCS bucket, 4 BigQuery datasets, service account + IAM bindings.
# Safe to re-run: every resource is checked before it is created; IAM bindings are idempotent.
# Usage: bash infra/setup.sh   (after `gcloud auth login` and filling in .env)
set -euo pipefail

cd "$(dirname "$0")/.."
if [[ ! -f .env ]]; then
  echo "ERROR: .env not found. Copy .env.example to .env and fill it in." >&2
  exit 1
fi
set -a; source .env; set +a

: "${GCP_PROJECT_ID:?GCP_PROJECT_ID must be set in .env}"
: "${BQ_LOCATION:?BQ_LOCATION must be set in .env}"
BUCKET="${GCS_BUCKET:-${GCP_PROJECT_ID}-olist-raw}"
SA_NAME="etl-pipeline-sa"
SA_EMAIL="${SA_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
DATASETS=(olist_bronze olist_silver olist_gold olist_ops)

echo "==> Project: ${GCP_PROJECT_ID} | Location: ${BQ_LOCATION} | Bucket: gs://${BUCKET}"
gcloud config set project "${GCP_PROJECT_ID}" >/dev/null

echo "==> Enabling required APIs (BigQuery, Cloud Storage, IAM)"
gcloud services enable bigquery.googleapis.com storage.googleapis.com iam.googleapis.com

echo "==> GCS bucket"
if gcloud storage buckets describe "gs://${BUCKET}" >/dev/null 2>&1; then
  echo "    gs://${BUCKET} already exists"
else
  gcloud storage buckets create "gs://${BUCKET}" \
    --project="${GCP_PROJECT_ID}" \
    --location="${BQ_LOCATION}" \
    --uniform-bucket-level-access
fi

echo "==> BigQuery datasets"
for ds in "${DATASETS[@]}"; do
  if bq show --format=none "${GCP_PROJECT_ID}:${ds}" >/dev/null 2>&1; then
    echo "    ${ds} already exists"
  else
    bq --location="${BQ_LOCATION}" mk --dataset "${GCP_PROJECT_ID}:${ds}"
  fi
done

echo "==> Service account"
if gcloud iam service-accounts describe "${SA_EMAIL}" >/dev/null 2>&1; then
  echo "    ${SA_EMAIL} already exists"
else
  gcloud iam service-accounts create "${SA_NAME}" \
    --display-name="Olist ETL pipeline" \
    --description="Runs the scheduled Olist ETL pipeline"
  echo "    waiting 15s for the new service account to propagate..."
  sleep 15
fi

echo "==> IAM bindings"
for role in roles/bigquery.dataEditor roles/bigquery.jobUser; do
  gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
    --member="serviceAccount:${SA_EMAIL}" --role="${role}" \
    --condition=None --quiet >/dev/null
  echo "    granted ${role} (project)"
done
gcloud storage buckets add-iam-policy-binding "gs://${BUCKET}" \
  --member="serviceAccount:${SA_EMAIL}" --role="roles/storage.objectViewer" >/dev/null
echo "    granted roles/storage.objectViewer (bucket gs://${BUCKET})"

echo "==> Done. Next: python ingestion/upload_to_gcs.py"
