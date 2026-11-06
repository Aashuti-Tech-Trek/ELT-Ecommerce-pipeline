-- Data-quality checks DQ01-DQ14.
-- ONE query; each branch returns exactly one row: (check_id, check_name, table_name, severity, violations).
-- A check passes when violations = 0. The orchestrator adds run_id, passed, checked_at and appends
-- every row to olist_ops.data_quality_log, so all checks always run even if one fails.
-- No freshness check: the dataset is a static snapshot of historical data.

SELECT 'DQ01' AS check_id, 'order_id not null' AS check_name, 'fact_orders' AS table_name, 'ERROR' AS severity,
       COUNTIF(order_id IS NULL) AS violations
FROM olist_gold.fact_orders

UNION ALL
SELECT 'DQ02', 'customer_key not null', 'fact_orders', 'ERROR',
       COUNTIF(customer_key IS NULL)
FROM olist_gold.fact_orders

UNION ALL
SELECT 'DQ03', 'order_id unique', 'fact_orders', 'ERROR',
       COUNT(*) - COUNT(DISTINCT order_id)
FROM olist_gold.fact_orders

UNION ALL
SELECT 'DQ04', 'customer_key exists in dim_customers', 'fact_orders', 'ERROR',
       COUNTIF(d.customer_key IS NULL)
FROM olist_gold.fact_orders AS f
LEFT JOIN olist_gold.dim_customers AS d ON d.customer_key = f.customer_key

UNION ALL
SELECT 'DQ05', 'order_date_key exists in dim_date', 'fact_orders', 'ERROR',
       COUNTIF(d.date_key IS NULL)
FROM olist_gold.fact_orders AS f
LEFT JOIN olist_gold.dim_date AS d ON d.date_key = f.order_date_key

UNION ALL
SELECT 'DQ06', 'review_score null or between 1 and 5', 'fact_orders', 'ERROR',
       COUNTIF(review_score IS NOT NULL AND review_score NOT BETWEEN 1 AND 5)
FROM olist_gold.fact_orders

UNION ALL
SELECT 'DQ07', 'total_price and total_freight_value >= 0', 'fact_orders', 'ERROR',
       COUNTIF(total_price < 0 OR total_freight_value < 0)
FROM olist_gold.fact_orders

UNION ALL
SELECT 'DQ08', 'payment_value >= 0', 'fact_orders', 'ERROR',
       COUNTIF(payment_value < 0)
FROM olist_gold.fact_orders

UNION ALL
SELECT 'DQ09', 'row count equals olist_silver.orders', 'fact_orders', 'ERROR',
       ABS((SELECT COUNT(*) FROM olist_gold.fact_orders) - (SELECT COUNT(*) FROM olist_silver.orders))

UNION ALL
SELECT 'DQ10', 'customer_key unique', 'dim_customers', 'ERROR',
       COUNT(*) - COUNT(DISTINCT customer_key)
FROM olist_gold.dim_customers

UNION ALL
SELECT 'DQ11', 'product_key unique', 'dim_products', 'ERROR',
       COUNT(*) - COUNT(DISTINCT product_key)
FROM olist_gold.dim_products

UNION ALL
SELECT 'DQ12', 'seller_key unique', 'dim_sellers', 'ERROR',
       COUNT(*) - COUNT(DISTINCT seller_key)
FROM olist_gold.dim_sellers

UNION ALL
SELECT 'DQ13', 'product_key exists in dim_products', 'rpt_product_sales', 'WARN',
       COUNTIF(p.product_key IS NULL)
FROM olist_gold.rpt_product_sales AS r
LEFT JOIN olist_gold.dim_products AS p ON p.product_key = r.product_key

UNION ALL
SELECT 'DQ14', 'delivery_days null or >= 0', 'fact_orders', 'WARN',
       COUNTIF(delivery_days < 0)
FROM olist_gold.fact_orders
