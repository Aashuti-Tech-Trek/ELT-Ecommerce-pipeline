-- Gold: flat reporting table, one row per ORDER ITEM, for the "Product performance" dashboard page.
-- Exists because fact_orders is order-grain and cannot carry per-product data without violating 1NF.
-- It is NOT the star-schema fact table.
CREATE OR REPLACE TABLE olist_gold.rpt_product_sales AS
SELECT
  i.order_id,
  i.order_item_id,
  DATE(o.order_purchase_ts) AS order_date_key,
  o.order_status,
  i.product_id AS product_key,
  i.seller_id AS seller_key,
  COALESCE(p.product_category_name_english, 'unknown') AS product_category_name_english,
  i.price,
  i.freight_value
FROM olist_silver.order_items AS i
INNER JOIN olist_silver.orders AS o ON o.order_id = i.order_id
LEFT JOIN olist_gold.dim_products AS p ON p.product_key = i.product_id;
