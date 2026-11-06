-- Gold: customer dimension. Natural key used as the key (no surrogate keys).
-- NOTE: customer_id is per-order in Olist; customer_unique_id identifies the real person.
CREATE OR REPLACE TABLE olist_gold.dim_customers AS
SELECT
  customer_id AS customer_key,
  customer_unique_id,
  customer_city,
  customer_state,
  customer_zip_prefix
FROM olist_silver.customers;
