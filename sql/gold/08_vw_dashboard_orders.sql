-- Gold: semantic/reporting view for BI consumption (Looker Studio).
-- Pre-joins fact_orders with dim_date and dim_customers to simplify dashboard creation.
CREATE OR REPLACE VIEW olist_gold.vw_dashboard_orders AS
SELECT
  f.order_id,
  f.customer_key,
  f.order_date_key,
  d.year,
  d.month,
  d.year_month,
  d.day_name,
  f.order_status,
  f.payment_value,
  f.total_price,
  f.total_freight_value,
  f.item_count,
  f.payment_type,
  f.review_score,
  f.delivery_days,
  c.customer_unique_id,
  c.customer_state,
  CONCAT('BR-', c.customer_state) AS customer_state_iso,
  c.customer_city,
  c.customer_zip_prefix
FROM olist_gold.fact_orders f
LEFT JOIN olist_gold.dim_date d
  ON f.order_date_key = d.date_key
LEFT JOIN olist_gold.dim_customers c
  ON f.customer_key = c.customer_key;
