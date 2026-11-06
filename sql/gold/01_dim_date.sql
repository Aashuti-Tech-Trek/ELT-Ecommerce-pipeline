-- Gold: date dimension, generated (not hand-written) for every day in the order date range.
CREATE OR REPLACE TABLE olist_gold.dim_date AS
WITH bounds AS (
  SELECT
    MIN(DATE(order_purchase_ts)) AS min_date,
    MAX(DATE(order_purchase_ts)) AS max_date
  FROM olist_silver.orders
)
SELECT
  d AS date_key,
  EXTRACT(YEAR FROM d) AS year,
  EXTRACT(QUARTER FROM d) AS quarter,
  EXTRACT(MONTH FROM d) AS month,
  FORMAT_DATE('%B', d) AS month_name,
  FORMAT_DATE('%Y-%m', d) AS year_month,
  EXTRACT(DAYOFWEEK FROM d) AS day_of_week,          -- 1 = Sunday ... 7 = Saturday
  FORMAT_DATE('%A', d) AS day_name,
  EXTRACT(DAYOFWEEK FROM d) IN (1, 7) AS is_weekend
FROM bounds, UNNEST(GENERATE_DATE_ARRAY(min_date, max_date, INTERVAL 1 DAY)) AS d;
