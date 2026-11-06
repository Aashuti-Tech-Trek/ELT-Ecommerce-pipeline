-- Silver: Portuguese -> English category names. One row per Portuguese category.
CREATE OR REPLACE TABLE olist_silver.product_category_translation AS
SELECT
  TRIM(product_category_name) AS product_category_name,
  TRIM(product_category_name_english) AS product_category_name_english
FROM olist_bronze.product_category_translation
WHERE product_category_name IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(product_category_name) ORDER BY _loaded_at DESC) = 1;
