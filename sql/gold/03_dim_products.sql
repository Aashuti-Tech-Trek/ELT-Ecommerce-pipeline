-- Gold: product dimension. English category falls back to the Portuguese name (2 categories have no
-- translation row) and then to 'unknown' (products with a NULL category).
CREATE OR REPLACE TABLE olist_gold.dim_products AS
SELECT
  p.product_id AS product_key,
  p.product_category_name,
  COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS product_category_name_english,
  p.product_weight_g,
  p.product_length_cm,
  p.product_height_cm,
  p.product_width_cm
FROM olist_silver.products AS p
LEFT JOIN olist_silver.product_category_translation AS t
  ON t.product_category_name = p.product_category_name;
