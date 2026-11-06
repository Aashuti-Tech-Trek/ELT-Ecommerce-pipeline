-- Silver: orders. One row per order_id; statuses normalised; timestamp columns renamed to *_ts.
CREATE OR REPLACE TABLE olist_silver.orders AS
SELECT
  TRIM(order_id) AS order_id,
  TRIM(customer_id) AS customer_id,
  LOWER(TRIM(order_status)) AS order_status,
  CAST(order_purchase_timestamp AS TIMESTAMP) AS order_purchase_ts,
  CAST(order_approved_at AS TIMESTAMP) AS order_approved_ts,
  CAST(order_delivered_carrier_date AS TIMESTAMP) AS order_delivered_carrier_ts,
  CAST(order_delivered_customer_date AS TIMESTAMP) AS order_delivered_customer_ts,
  CAST(order_estimated_delivery_date AS TIMESTAMP) AS order_estimated_delivery_ts
FROM olist_bronze.orders
WHERE order_id IS NOT NULL
  AND customer_id IS NOT NULL
  AND order_purchase_timestamp IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(order_id) ORDER BY _loaded_at DESC) = 1;
