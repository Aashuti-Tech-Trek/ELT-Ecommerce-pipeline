-- Silver: order line items. One row per (order_id, order_item_id); negative amounts dropped.
CREATE OR REPLACE TABLE olist_silver.order_items AS
SELECT
  TRIM(order_id) AS order_id,
  CAST(order_item_id AS INT64) AS order_item_id,
  TRIM(product_id) AS product_id,
  TRIM(seller_id) AS seller_id,
  CAST(shipping_limit_date AS TIMESTAMP) AS shipping_limit_ts,
  CAST(price AS NUMERIC) AS price,
  CAST(freight_value AS NUMERIC) AS freight_value
FROM olist_bronze.order_items
WHERE order_id IS NOT NULL
  AND order_item_id IS NOT NULL
  AND product_id IS NOT NULL
  AND price >= 0
  AND freight_value >= 0
QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(order_id), order_item_id ORDER BY _loaded_at DESC) = 1;
