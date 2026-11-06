"""Upload the 9 Olist CSVs from data/raw/ to gs://<GCS_BUCKET>/raw/<filename> (raw zone).

The raw zone is immutable: files are uploaded byte-for-byte, no modification.
Usage: python ingestion/upload_to_gcs.py
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

from dotenv import load_dotenv
from google.cloud import storage

ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = ROOT / "data" / "raw"

# Mapping from raw CSV file to bronze table name.
SOURCE_FILES: dict[str, str] = {
    "olist_orders_dataset.csv": "orders",
    "olist_order_items_dataset.csv": "order_items",
    "olist_order_payments_dataset.csv": "order_payments",
    "olist_order_reviews_dataset.csv": "order_reviews",
    "olist_customers_dataset.csv": "customers",
    "olist_products_dataset.csv": "products",
    "olist_sellers_dataset.csv": "sellers",
    "olist_geolocation_dataset.csv": "geolocation",
    "product_category_name_translation.csv": "product_category_translation",
}


def main() -> int:
    load_dotenv(ROOT / ".env")
    project = os.getenv("GCP_PROJECT_ID")
    bucket_name = os.getenv("GCS_BUCKET")
    if not project or not bucket_name:
        print("ERROR: GCP_PROJECT_ID and GCS_BUCKET must be set in .env", file=sys.stderr)
        return 1

    missing = [f for f in SOURCE_FILES if not (RAW_DIR / f).is_file()]
    if missing:
        print(f"ERROR: missing files in {RAW_DIR}:", *missing, sep="\n  ", file=sys.stderr)
        return 1

    bucket = storage.Client(project=project).bucket(bucket_name)
    for filename in SOURCE_FILES:
        local = RAW_DIR / filename
        blob = bucket.blob(f"raw/{filename}")
        size_mb = local.stat().st_size / 1_048_576
        print(f"Uploading {filename} ({size_mb:.1f} MB) -> gs://{bucket_name}/raw/{filename}", flush=True)
        blob.upload_from_filename(str(local), timeout=600)

    print(f"Done: {len(SOURCE_FILES)} files uploaded.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
