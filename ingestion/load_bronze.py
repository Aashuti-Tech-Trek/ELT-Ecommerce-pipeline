"""Load the raw GCS CSVs into BigQuery olist_bronze.* datasets.

Per table:
  1. Load gs://<bucket>/raw/<file> into olist_bronze._stg_<table> using the explicit
     schema in ingestion/schemas/<table>.json (no autodetect).
  2. CREATE OR REPLACE olist_bronze.<table> = staging + _loaded_at + _source_file.
  3. Drop the staging table.
Bronze performs no cleaning. Re-running fully replaces every bronze table.
Usage: python ingestion/load_bronze.py
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

from dotenv import load_dotenv
from google.cloud import bigquery

sys.path.insert(0, str(Path(__file__).resolve().parent))
from upload_to_gcs import SOURCE_FILES  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SCHEMA_DIR = ROOT / "ingestion" / "schemas"
DATASET = "olist_bronze"


def load_table(client: bigquery.Client, project: str, bucket: str, filename: str, table: str) -> int:
    uri = f"gs://{bucket}/raw/{filename}"
    staging = f"{project}.{DATASET}._stg_{table}"
    final = f"{project}.{DATASET}.{table}"

    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.CSV,
        skip_leading_rows=1,
        allow_quoted_newlines=True,  # review comments contain embedded newlines
        encoding="UTF-8",
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        schema=client.schema_from_json(str(SCHEMA_DIR / f"{table}.json")),
    )
    try:
        load_job = client.load_table_from_uri(uri, staging, job_config=job_config)
        try:
            load_job.result()
        except Exception:
            for err in load_job.errors or []:
                print(f"    load error: {err}", file=sys.stderr)
            raise

        client.query(
            f"CREATE OR REPLACE TABLE `{final}` AS "
            f"SELECT *, CURRENT_TIMESTAMP() AS _loaded_at, '{uri}' AS _source_file "
            f"FROM `{staging}`"
        ).result()
    finally:
        client.delete_table(staging, not_found_ok=True)

    return client.get_table(final).num_rows


def main() -> int:
    load_dotenv(ROOT / ".env")
    project = os.getenv("GCP_PROJECT_ID")
    bucket = os.getenv("GCS_BUCKET")
    location = os.getenv("BQ_LOCATION")
    if not project or not bucket or not location:
        print("ERROR: GCP_PROJECT_ID, GCS_BUCKET and BQ_LOCATION must be set in .env", file=sys.stderr)
        return 1

    client = bigquery.Client(project=project, location=location)
    for filename, table in SOURCE_FILES.items():
        print(f"Loading {filename} -> {DATASET}.{table} ...", flush=True)
        try:
            rows = load_table(client, project, bucket, filename, table)
        except Exception as exc:
            print(f"FAILED {DATASET}.{table}: {exc}", file=sys.stderr)
            return 1
        print(f"  OK {DATASET}.{table}: {rows:,} rows")

    print("Bronze load complete. Next: pytest tests/ (with RUN_GCP_TESTS=1)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
