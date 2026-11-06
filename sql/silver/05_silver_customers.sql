-- Silver: customers. One row per customer_id (Olist issues a new customer_id per order;
-- customer_unique_id identifies the person). Zip prefixes are left-padded to 5 digits because
-- the source CSV dropped leading zeros (e.g. '9790' -> '09790'), so they join to geolocation.
CREATE OR REPLACE TABLE olist_silver.customers AS
SELECT
  TRIM(customer_id) AS customer_id,
  TRIM(customer_unique_id) AS customer_unique_id,
  LPAD(TRIM(customer_zip_code_prefix), 5, '0') AS customer_zip_prefix,
  LOWER(TRIM(customer_city)) AS customer_city,
  UPPER(TRIM(customer_state)) AS customer_state
FROM olist_bronze.customers
WHERE customer_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(customer_id) ORDER BY _loaded_at DESC) = 1;
