-- Gold: seller dimension.
CREATE OR REPLACE TABLE olist_gold.dim_sellers AS
SELECT
  seller_id AS seller_key,
  seller_city,
  seller_state,
  seller_zip_prefix
FROM olist_silver.sellers;
