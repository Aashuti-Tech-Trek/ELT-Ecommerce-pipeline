-- Silver: payments. One row per (order_id, payment_sequential); payment_type normalised.
CREATE OR REPLACE TABLE olist_silver.order_payments AS
SELECT
  TRIM(order_id) AS order_id,
  CAST(payment_sequential AS INT64) AS payment_sequential,
  LOWER(TRIM(payment_type)) AS payment_type,
  CAST(payment_installments AS INT64) AS payment_installments,
  CAST(payment_value AS NUMERIC) AS payment_value
FROM olist_bronze.order_payments
WHERE order_id IS NOT NULL
  AND payment_value >= 0
QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(order_id), payment_sequential ORDER BY _loaded_at DESC) = 1;
