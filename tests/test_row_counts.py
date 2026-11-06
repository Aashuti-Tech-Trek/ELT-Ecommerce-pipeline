"""Tests for the bronze layer.

Offline tests (always run, no GCP needed - run these as soon as the CSVs are in data/raw/):
  * all 9 source files are present
  * each CSV header matches its pinned schema in ingestion/schemas/ exactly (names and order)

GCP test (runs only after Step 5 and only with RUN_GCP_TESTS=1):
  * row count of every local CSV == num_rows of its olist_bronze table

Usage:
  pytest tests/ -v                     # offline only
  RUN_GCP_TESTS=1 pytest tests/ -v     # offline + bronze row counts
"""
from __future__ import annotations

import csv
import json
import os
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = ROOT / "data" / "raw"
SCHEMA_DIR = ROOT / "ingestion" / "schemas"
sys.path.insert(0, str(ROOT / "ingestion"))
from upload_to_gcs import SOURCE_FILES  # noqa: E402

csv.field_size_limit(sys.maxsize)
CASES = list(SOURCE_FILES.items())
IDS = [table for _, table in CASES]


def read_header(path: Path) -> list[str]:
    # utf-8-sig strips the BOM present in product_category_name_translation.csv
    with path.open(newline="", encoding="utf-8-sig") as fh:
        return next(csv.reader(fh))


def count_data_rows(path: Path) -> int:
    # csv.reader (not line counting) because review comments contain quoted newlines
    with path.open(newline="", encoding="utf-8-sig") as fh:
        return sum(1 for _ in csv.reader(fh)) - 1


def test_all_source_files_present() -> None:
    missing = [f for f in SOURCE_FILES if not (RAW_DIR / f).is_file()]
    assert not missing, f"missing in data/raw/: {missing}"


@pytest.mark.parametrize("filename,table", CASES, ids=IDS)
def test_header_matches_schema(filename: str, table: str) -> None:
    path = RAW_DIR / filename
    if not path.is_file():
        pytest.skip(f"{filename} not downloaded yet")
    schema = json.loads((SCHEMA_DIR / f"{table}.json").read_text())
    assert read_header(path) == [field["name"] for field in schema]


@pytest.mark.skipif(os.getenv("RUN_GCP_TESTS") != "1", reason="set RUN_GCP_TESTS=1 after bronze is loaded")
@pytest.mark.parametrize("filename,table", CASES, ids=IDS)
def test_bronze_row_count_matches_csv(filename: str, table: str) -> None:
    from dotenv import load_dotenv
    from google.cloud import bigquery

    load_dotenv(ROOT / ".env")
    client = bigquery.Client(project=os.environ["GCP_PROJECT_ID"], location=os.environ["BQ_LOCATION"])
    bq_rows = client.get_table(f"{os.environ['GCP_PROJECT_ID']}.olist_bronze.{table}").num_rows
    assert bq_rows == count_data_rows(RAW_DIR / filename)
