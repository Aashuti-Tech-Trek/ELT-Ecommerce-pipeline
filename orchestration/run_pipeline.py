"""Pipeline orchestrator for the BigQuery ETL workflow.

Runs, in order:  silver (sql/silver/*.sql)  ->  gold (sql/gold/*.sql)  ->  quality (DQ checks)
Files within a stage run in filename order (01_, 02_, ...), which encodes the dependencies.
Bronze loading (ingestion/) is a separate, manual step and is NOT run here.

Usage:  python orchestration/run_pipeline.py [--stage silver|gold|quality|all]
Exit code 0 = success; 1 = a SQL file failed, or an ERROR-severity quality check failed.
Used unchanged both locally (ADC credentials) and as the Cloud Run job entry point (Step 10).
"""
from __future__ import annotations

import argparse
import os
import re
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

from dotenv import load_dotenv
from google.cloud import bigquery

ROOT = Path(__file__).resolve().parent.parent
SQL_DIR = ROOT / "sql"
LOG_TABLE = "olist_ops.data_quality_log"
STAGES = ("silver", "gold", "quality")
TARGET_RE = re.compile(r"CREATE\s+OR\s+REPLACE\s+TABLE\s+`?([\w-]+\.[\w-]+)`?", re.IGNORECASE)


class StageError(Exception):
    """A SQL file failed; the pipeline must stop."""


def run_sql_stage(client: bigquery.Client, project: str, stage: str) -> None:
    files = sorted((SQL_DIR / stage).glob("*.sql"))
    if not files:
        raise StageError(f"no SQL files found in sql/{stage}/")
    for path in files:
        sql = path.read_text(encoding="utf-8")
        print(f"[{stage}] {path.name} ...", end=" ", flush=True)
        started = time.monotonic()
        try:
            client.query(sql).result()
        except Exception as exc:  # any BigQuery error stops the run
            print("FAILED")
            raise StageError(f"{path.name}: {exc}") from exc
        match = TARGET_RE.search(sql)
        if match:
            rows = client.get_table(f"{project}.{match.group(1)}").num_rows
            print(f"OK  {match.group(1)} = {rows:,} rows ({time.monotonic() - started:.1f}s)")
        else:
            print(f"OK ({time.monotonic() - started:.1f}s)")


def run_quality_stage(client: bigquery.Client, project: str, run_id: str) -> bool:
    """Run all DQ checks, append results to the log table. Returns False if any ERROR check failed."""
    try:
        client.query((SQL_DIR / "quality" / "create_log_table.sql").read_text(encoding="utf-8")).result()
        results = list(client.query((SQL_DIR / "quality" / "checks.sql").read_text(encoding="utf-8")).result())
    except Exception as exc:
        raise StageError(f"quality checks could not run: {exc}") from exc

    checked_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S.%f")
    records = [
        {
            "run_id": run_id,
            "check_id": r["check_id"],
            "check_name": r["check_name"],
            "table_name": r["table_name"],
            "severity": r["severity"],
            "violations": int(r["violations"]),
            "passed": int(r["violations"]) == 0,
            "checked_at": checked_at,
        }
        for r in results
    ]
    records.sort(key=lambda rec: rec["check_id"])

    # Batch load job (not streaming insert): free, and works immediately after table creation.
    log_table = client.get_table(f"{project}.{LOG_TABLE}")
    job_config = bigquery.LoadJobConfig(
        schema=log_table.schema,
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
    )
    client.load_table_from_json(records, log_table, job_config=job_config).result()

    print(f"\n{'ID':<6}{'SEVERITY':<10}{'RESULT':<8}{'VIOLATIONS':>11}  CHECK")
    for rec in records:
        result = "PASS" if rec["passed"] else "FAIL"
        print(f"{rec['check_id']:<6}{rec['severity']:<10}{result:<8}{rec['violations']:>11,}  "
              f"{rec['table_name']}: {rec['check_name']}")
    errors = [r for r in records if not r["passed"] and r["severity"] == "ERROR"]
    warns = [r for r in records if not r["passed"] and r["severity"] == "WARN"]
    print(f"\n{len(records) - len(errors) - len(warns)}/{len(records)} checks passed, "
          f"{len(errors)} ERROR failure(s), {len(warns)} WARN failure(s). Logged to {LOG_TABLE} (run_id={run_id})")
    return not errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Run the Olist ETL pipeline inside BigQuery.")
    parser.add_argument("--stage", choices=(*STAGES, "all"), default="all")
    args = parser.parse_args(argv)

    load_dotenv(ROOT / ".env")  # no-op on Cloud Run, where env vars are set on the job
    project = os.getenv("GCP_PROJECT_ID")
    location = os.getenv("BQ_LOCATION")
    if not project or not location:
        print("ERROR: GCP_PROJECT_ID and BQ_LOCATION must be set (.env or environment)", file=sys.stderr)
        return 1

    run_id = str(uuid.uuid4())
    stages = STAGES if args.stage == "all" else (args.stage,)
    print(f"Pipeline run {run_id} | project={project} location={location} stages={','.join(stages)}")
    client = bigquery.Client(project=project, location=location)
    started = time.monotonic()

    try:
        quality_ok = True
        for stage in stages:
            print(f"\n=== {stage.upper()} ===")
            if stage == "quality":
                quality_ok = run_quality_stage(client, project, run_id)
            else:
                run_sql_stage(client, project, stage)
    except StageError as exc:
        print(f"\nPIPELINE FAILED: {exc}", file=sys.stderr)
        return 1

    elapsed = time.monotonic() - started
    if not quality_ok:
        print(f"\nPIPELINE FINISHED WITH ERROR-SEVERITY QUALITY FAILURES ({elapsed:.0f}s)", file=sys.stderr)
        return 1
    print(f"\nPIPELINE SUCCEEDED ({elapsed:.0f}s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
