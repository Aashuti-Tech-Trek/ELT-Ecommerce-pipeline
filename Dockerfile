# Container for the scheduled pipeline run (Cloud Run job, Step 10).
# Only the orchestrator + SQL are needed at run time; ingestion is a manual, separate step.
FROM python:3.12-slim

WORKDIR /app
ENV PYTHONUNBUFFERED=1

RUN pip install --no-cache-dir "google-cloud-bigquery>=3.20" "python-dotenv>=1.0"

COPY orchestration/ orchestration/
COPY sql/ sql/

ENTRYPOINT ["python", "orchestration/run_pipeline.py"]
