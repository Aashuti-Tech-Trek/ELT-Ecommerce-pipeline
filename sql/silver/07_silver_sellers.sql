-- Silver: sellers. One row per seller_id. Zip prefix left-padded to 5 digits (see 05_silver_customers.sql).
CREATE OR REPLACE TABLE olist_silver.sellers AS
SELECT
  TRIM(seller_id) AS seller_id,
  LPAD(TRIM(seller_zip_code_prefix), 5, '0') AS seller_zip_prefix,
  LOWER(TRIM(seller_city)) AS seller_city,
  UPPER(TRIM(seller_state)) AS seller_state
FROM olist_bronze.sellers
WHERE seller_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(seller_id) ORDER BY _loaded_at DESC) = 1;
