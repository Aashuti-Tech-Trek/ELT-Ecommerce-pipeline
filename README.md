# Cloud-Native Batch ETL Pipeline for E-Commerce Sales Analytics

An automated, scheduled batch ETL pipeline that ingests the Olist Brazilian E-Commerce dataset into Google Cloud Storage, transforms and models it natively in Google BigQuery into a star schema, enforces data quality via SQL validation checks, and exposes the warehouse to Looker Studio dashboards.

---

## 1. Project Information
- **Course**: CS404 – Big Data Analytics
- **Team**:
  - Arihant Yadav (2023BCS-011)
  - Aashuti Gambhir (2023BCS-001)
  - Dhrushit Jain (2023BCS-019)
- **Dataset**: Olist Brazilian E-Commerce Public Dataset (9 CSV files, ~120 MB)
- **Cloud Provider**: Google Cloud Platform (GCP)
- **GCP Region**: `asia-south1` (Mumbai)

---

## 2. Technology Stack & Architecture
- **Raw Zone Landing Area**: Google Cloud Storage (`gs://<PROJECT_ID>-olist-raw/raw/`)
- **Data Warehouse**: Google BigQuery (Medallion architecture: `olist_bronze`, `olist_silver`, `olist_gold`, `olist_ops`)
- **Transformations**: BigQuery-native SQL (`CREATE OR REPLACE TABLE`)
- **Data Quality**: SQL assertions (DQ01–DQ14) logged to `olist_ops.data_quality_log`
- **Orchestration**: Python orchestrator (`run_pipeline.py`) deployed as a Cloud Run Job, scheduled via Cloud Scheduler (daily at 02:00 IST)
- **BI & Visualizations**: Looker Studio connected exclusively to `olist_gold`

---

## 3. Directory Layout
```
ecommerce-etl-pipeline/
├── README.md                   # Quick start and overview
├── requirements.txt            # Python dependencies (BigQuery, Storage, pytest, etc.)
├── .gitignore                  # Ignores data/, .env, venv/, but tracks schema JSONs
├── .env.example                # Template for GCP credentials and config
├── Dockerfile                  # Container definition for Cloud Run job
├── data/raw/                   # Landing zone for local Kaggle CSVs (gitignored)
├── infra/
│   └── setup.sh                # Idempotent GCP provisioning (Bucket, Datasets, SA, IAM)
├── ingestion/
│   ├── schemas/*.json          # Pinned BigQuery schemas for the 9 bronze tables
│   ├── upload_to_gcs.py        # Uploads raw CSVs to GCS immutable bucket
│   └── load_bronze.py          # Loads GCS CSVs into BigQuery bronze tables + audit columns
├── sql/
│   ├── silver/                 # 9 SQL scripts for cleaning and deduplicating
│   ├── gold/                   # 7 SQL scripts (5 dimensions, 1 fact, 1 reporting table)
│   └── quality/                # DDL for quality log + checks DQ01-DQ14
├── orchestration/
│   ├── run_pipeline.py         # Stage-based orchestrator (--stage silver|gold|quality|all)
│   └── schedule_setup.sh       # Deploys Cloud Run job & Cloud Scheduler trigger
├── dashboards/
│   └── looker_studio_notes.md  # Looker Studio connection details and calculated fields
├── tests/
│   └── test_row_counts.py      # Pytest validation (offline schema checks + online row counts)
└── docs/
    └── star_schema.md          # Dimensional model, table grains, and column dictionary
```

---

## 4. Quick Start (Execution Order)

### Step 1: Environment Setup
```bash
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your GCP_PROJECT_ID, GCS_BUCKET, and BQ_LOCATION=asia-south1
```

### Step 2: Download Dataset
Place the 9 Olist CSVs into `data/raw/`:
```bash
# Using Kaggle API (if ~/.kaggle/kaggle.json exists):
kaggle datasets download -d olistbr/brazilian-ecommerce -p data/raw --unzip
```
Verify offline with pytest:
```bash
pytest tests/ -v
```

### Step 3: Provision GCP Infrastructure (Once Credits are Ready)
Authenticate to GCP with Application Default Credentials:
```bash
gcloud auth login
gcloud auth application-default login
bash infra/setup.sh
```

### Step 4: Ingest Data into GCS and Bronze
```bash
python ingestion/upload_to_gcs.py
python ingestion/load_bronze.py
RUN_GCP_TESTS=1 pytest tests/ -v
```

### Step 5: Run the Transformation Pipeline
```bash
python orchestration/run_pipeline.py --stage all
```

### Step 6: Deploy Scheduling (Step 10)
```bash
bash orchestration/schedule_setup.sh
```

### Step 7: Build Looker Studio Dashboards
Connect Looker Studio to `olist_gold` and build the 3 dashboard pages detailed in `dashboards/looker_studio_notes.md`.
