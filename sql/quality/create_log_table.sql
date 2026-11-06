-- Data-quality log. Appended to on every pipeline run (never replaced), one row per check per run.
CREATE TABLE IF NOT EXISTS olist_ops.data_quality_log (
  run_id STRING,
  check_id STRING,
  check_name STRING,
  table_name STRING,
  severity STRING,      -- 'ERROR' fails the run, 'WARN' is reported only
  violations INT64,     -- number of offending rows; 0 = pass
  passed BOOL,
  checked_at TIMESTAMP
);
