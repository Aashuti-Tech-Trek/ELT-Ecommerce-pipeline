# Olist E-Commerce Star Schema & Data Model

## 1. Architectural Overview
The warehouse models the Olist E-Commerce dataset within BigQuery's `olist_gold` dataset following a **Medallion Architecture**:
- **`olist_bronze`**: Raw tables loaded directly from GCS with explicit JSON schemas + ingestion audit columns (`_loaded_at`, `_source_file`).
- **`olist_silver`**: Cleaned, typed, deduplicated (via `QUALIFY ROW_NUMBER()`), and filtered domain tables.
- **`olist_gold`**: Star-schema dimensional model serving reporting queries and Looker Studio dashboards.

---

## 2. Fact Table: `olist_gold.fact_orders`
- **Grain**: **One row per order**.
- **Partitioning**: `PARTITION BY order_date_key` (optimizes date-range time series queries in Looker Studio).
- **Clustering**: `CLUSTER BY customer_key` (co-locates data by customer for high-performance joins).

| Column | Type | Description & Source Logic |
| :--- | :--- | :--- |
| `order_id` | STRING | Primary Key, from `silver.orders` |
| `customer_key` | STRING | Foreign Key -> `dim_customers.customer_key` (`orders.customer_id`) |
| `order_date_key` | DATE | Foreign Key -> `dim_date.date_key` (`DATE(order_purchase_ts)`) |
| `order_status` | STRING | Normalized order lifecycle status (`delivered`, `shipped`, etc.) |
| `total_price` | NUMERIC | `SUM(price)` of items in the order (`COALESCE(..., 0)`) |
| `total_freight_value` | NUMERIC | `SUM(freight_value)` of items in the order (`COALESCE(..., 0)`) |
| `item_count` | INT64 | Total line items in the order (`COALESCE(..., 0)`) |
| `payment_value` | NUMERIC | Total amount paid across all payment installments (`COALESCE(..., 0)`) |
| `payment_type` | STRING | Dominant payment method (highest payment value; ties broken by sequence) |
| `review_score` | INT64 | Review rating (1-5) from latest customer review |
| `delivery_days` | INT64 | `DATE_DIFF(delivered_date, purchase_date, DAY)`; `NULL` if not delivered |

---

## 3. Dimension Tables

### `olist_gold.dim_date`
Programmatically generated using BigQuery `GENERATE_DATE_ARRAY` covering every calendar date between the earliest and latest orders.
- `date_key` (DATE, Primary Key)
- `year` (INT64), `quarter` (INT64), `month` (INT64)
- `month_name` (STRING, e.g., 'October')
- `year_month` (STRING, formatted `'YYYY-MM'`)
- `day_of_week` (INT64, 1=Sunday ... 7=Saturday)
- `day_name` (STRING, e.g., 'Monday')
- `is_weekend` (BOOL, `day_of_week IN (1, 7)`)

### `olist_gold.dim_customers`
- `customer_key` (STRING, Primary Key = `customer_id`)
- `customer_unique_id` (STRING, real-world customer identifier)
- `customer_city` (STRING, normalized lowercase/trimmed)
- `customer_state` (STRING, uppercase 2-letter state)
- `customer_zip_prefix` (STRING, 5-digit zero-padded Brazilian postal prefix)

*Note: In the Olist dataset, each purchase issues a new `customer_id`. `customer_unique_id` links repeat customers across multiple orders.*

### `olist_gold.dim_products`
Enriched with Portuguese -> English translations and handling missing translations.
- `product_key` (STRING, Primary Key = `product_id`)
- `product_category_name` (STRING, original Portuguese name)
- `product_category_name_english` (STRING, translated English category, falls back to Portuguese if untranslated, or `'unknown'` if null)
- `product_weight_g` (INT64), `product_length_cm` (INT64), `product_height_cm` (INT64), `product_width_cm` (INT64)

### `olist_gold.dim_sellers`
- `seller_key` (STRING, Primary Key = `seller_id`)
- `seller_city` (STRING, lowercase/trimmed)
- `seller_state` (STRING, uppercase 2-letter state)
- `seller_zip_prefix` (STRING, 5-digit zero-padded)

### `olist_gold.dim_geolocation`
Deduplicated Brazilian geographic coordinates aggregated to one row per postal code prefix:
- `zip_prefix` (STRING, Primary Key, 5-digit zero-padded)
- `city` (STRING, most frequent city name per zip prefix)
- `state` (STRING, most frequent state code per zip prefix)
- `lat` (FLOAT64, average latitude within Brazil bounding box)
- `lng` (FLOAT64, average longitude within Brazil bounding box)

---

## 4. Reporting Table: `olist_gold.rpt_product_sales`
Because the fact table grain is **one row per order**, an order containing multiple products cannot store product attributes without violating 1NF. 

To power the **Product Performance** dashboard page without requiring Looker Studio to join directly to `olist_silver`, a dedicated flat reporting table is materialized at the **order-item grain**:
- **Grain**: One row per order line item.
- **Columns**: `order_id`, `order_item_id`, `order_date_key`, `order_status`, `product_key`, `seller_key`, `product_category_name_english`, `price`, `freight_value`.
