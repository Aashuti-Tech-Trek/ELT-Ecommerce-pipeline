-- Silver: products. One row per product_id. The misspelled "lenght" columns and photo count
-- are dropped (not used downstream). Category translation happens in gold (dim_products).
CREATE OR REPLACE TABLE olist_silver.products AS
SELECT
  TRIM(product_id) AS product_id,
  TRIM(product_category_name) AS product_category_name,
  CAST(product_weight_g AS INT64) AS product_weight_g,
  CAST(product_length_cm AS INT64) AS product_length_cm,
  CAST(product_height_cm AS INT64) AS product_height_cm,
  CAST(product_width_cm AS INT64) AS product_width_cm
FROM olist_bronze.products
WHERE product_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(product_id) ORDER BY _loaded_at DESC) = 1;
