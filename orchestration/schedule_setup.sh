#!/usr/bin/env bash
# Deploy run_pipeline.py as a Cloud Run JOB and trigger it daily with Cloud Scheduler.
# Run ONLY after `python orchestration/run_pipeline.py` has succeeded locally (Step 9).
# Safe to re-run: the job is redeployed; the scheduler job is updated if it already exists.
# Usage: bash orchestration/schedule_setup.sh
set -euo pipefail

cd "$(dirname "$0")/.."
set -a; source .env; set +a
: "${GCP_PROJECT_ID:?}" "${BQ_LOCATION:?}"

JOB_NAME="olist-etl-pipeline"
SCHEDULER_JOB="olist-etl-daily"
SCHEDULE="0 2 * * *"          # 02:00 daily (open decision O6 default)
TIME_ZONE="Asia/Kolkata"
SA_EMAIL="etl-pipeline-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

# Cloud Run needs a region; BigQuery may be a multi-region.
case "${BQ_LOCATION}" in
  US|us) REGION="us-central1" ;;
  EU|eu) REGION="europe-west1" ;;
  *)     REGION="${BQ_LOCATION}" ;;
esac

gcloud config set project "${GCP_PROJECT_ID}" >/dev/null
echo "==> Enabling Cloud Run, Cloud Scheduler, Cloud Build, Artifact Registry APIs"
gcloud services enable run.googleapis.com cloudscheduler.googleapis.com \
  cloudbuild.googleapis.com artifactregistry.googleapis.com

echo "==> Building (Dockerfile) and deploying Cloud Run job '${JOB_NAME}' in ${REGION}"
gcloud run jobs deploy "${JOB_NAME}" \
  --source . \
  --region "${REGION}" \
  --service-account "${SA_EMAIL}" \
  --set-env-vars "GCP_PROJECT_ID=${GCP_PROJECT_ID},BQ_LOCATION=${BQ_LOCATION}" \
  --tasks 1 \
  --max-retries 0 \
  --task-timeout 3600s

echo "==> Allowing ${SA_EMAIL} to execute the job (used by Cloud Scheduler)"
gcloud run jobs add-iam-policy-binding "${JOB_NAME}" \
  --region "${REGION}" \
  --member "serviceAccount:${SA_EMAIL}" \
  --role "roles/run.invoker" >/dev/null

RUN_URI="https://run.googleapis.com/v2/projects/${GCP_PROJECT_ID}/locations/${REGION}/jobs/${JOB_NAME}:run"
SCHED_ARGS=(--location "${REGION}" --schedule "${SCHEDULE}" --time-zone "${TIME_ZONE}"
            --uri "${RUN_URI}" --http-method POST --oauth-service-account-email "${SA_EMAIL}")

echo "==> Cloud Scheduler job '${SCHEDULER_JOB}' (${SCHEDULE} ${TIME_ZONE})"
if gcloud scheduler jobs describe "${SCHEDULER_JOB}" --location "${REGION}" >/dev/null 2>&1; then
  gcloud scheduler jobs update http "${SCHEDULER_JOB}" "${SCHED_ARGS[@]}"
else
  gcloud scheduler jobs create http "${SCHEDULER_JOB}" "${SCHED_ARGS[@]}"
fi

cat <<EOF
==> Done.
Test now (don't wait for 02:00):
  gcloud run jobs execute ${JOB_NAME} --region ${REGION} --wait
  gcloud scheduler jobs run ${SCHEDULER_JOB} --location ${REGION}
Then check: Cloud Run > Jobs > ${JOB_NAME} > Executions (logs), and olist_ops.data_quality_log.
EOF
