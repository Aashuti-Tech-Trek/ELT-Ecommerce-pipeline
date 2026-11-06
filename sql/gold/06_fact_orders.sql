-- Gold: fact table. GRAIN = one row per order (all statuses; filtering happens in Looker Studio).
-- Partitioned by order date, clustered by customer.
CREATE OR REPLACE TABLE olist_gold.fact_orders
PARTITION BY order_date_key
CLUSTER BY customer_key
AS
WITH items AS (
  SELECT
    order_id,
    SUM(price) AS total_price,
    SUM(freight_value) AS total_freight_value,
    COUNT(*) AS item_count
  FROM olist_silver.order_items
  GROUP BY order_id
),
pay AS (
  SELECT order_id, SUM(payment_value) AS payment_value
  FROM olist_silver.order_payments
  GROUP BY order_id
),
pay_type AS (
  -- dominant method = the payment row with the highest value; ties -> lowest sequence number
  SELECT order_id, payment_type
  FROM olist_silver.order_payments
  QUALIFY ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY payment_value DESC, payment_sequential ASC) = 1
)
SELECT
  o.order_id,
  o.customer_id AS customer_key,
  DATE(o.order_purchase_ts) AS order_date_key,
  o.order_status,
  COALESCE(i.total_price, 0) AS total_price,
  COALESCE(i.total_freight_value, 0) AS total_freight_value,
  COALESCE(i.item_count, 0) AS item_count,
  COALESCE(p.payment_value, 0) AS payment_value,
  pt.payment_type,
  r.review_score,
  IF(o.order_delivered_customer_ts IS NULL, NULL,
     DATE_DIFF(DATE(o.order_delivered_customer_ts), DATE(o.order_purchase_ts), DAY)) AS delivery_days
FROM olist_silver.orders AS o
LEFT JOIN items AS i ON i.order_id = o.order_id
LEFT JOIN pay AS p ON p.order_id = o.order_id
LEFT JOIN pay_type AS pt ON pt.order_id = o.order_id
LEFT JOIN olist_silver.order_reviews AS r ON r.order_id = o.order_id;
