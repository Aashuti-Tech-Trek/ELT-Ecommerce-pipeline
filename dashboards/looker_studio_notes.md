# Looker Studio Integration Notes

## Data Source Connection
- **Connector**: Google BigQuery
- **Billing Project**: `YOUR_GCP_PROJECT_ID`
- **Dataset**: `olist_gold`
- **Rule**: Looker Studio connects **exclusively** to the `olist_gold` dataset. It does not read directly from `olist_silver` or `olist_bronze`.

---

## Metric Note (Important for Viva & Reports)
- **Pages 1 & 3 (Revenue Trends & Customer Segmentation)** measure revenue as **`payment_value`** (what customers actually paid, including freight and installment totals).
- **Page 2 (Product Performance)** measures revenue as item **`price`** (item gross sales value, excluding freight).
- **Why they do not match:** By design! Freight and order-level payment discounts/installments belong to the order as a whole (`fact_orders`), whereas line-item product sales belong to individual products (`rpt_product_sales`).

---

## Global Filter Rule
On all three pages, add a chart or page filter excluding non-completed orders:
- **Filter**: `order_status NOT IN ('canceled', 'unavailable')`

---

## Dashboard Pages & Visualizations

### Page 1: Revenue Trends
- **Primary Data Source**: `olist_gold.fact_orders` joined to `olist_gold.dim_date` on `order_date_key = date_key`
- **Visuals**:
  1. **Scorecards**:
     - Total Revenue: `SUM(payment_value)` (formatted as Currency BRL)
     - Order Count: `COUNT(order_id)`
     - Average Order Value (AOV): `SUM(payment_value) / COUNT(order_id)`
  2. **Time Series 1 (Monthly Revenue)**:
     - Dimension: `year_month` (or `date_key` aggregated by Year Month)
     - Metric: `SUM(payment_value)`
     - Breakdown: None
  3. **Time Series 2 (Monthly Order Volume)**:
     - Dimension: `year_month`
     - Metric: `COUNT(order_id)`

---

### Page 2: Product Performance
- **Primary Data Source**: `olist_gold.rpt_product_sales` (flat reporting table)
- **Visuals**:
  1. **Bar Chart (Top 10 Categories by Revenue)**:
     - Dimension: `product_category_name_english`
     - Metric: `SUM(price)`
     - Sort: `SUM(price)` descending
     - Limit: Top 10
  2. **Bar Chart (Top 10 Categories by Order Count)**:
     - Dimension: `product_category_name_english`
     - Metric: `COUNT_DISTINCT(order_id)`
     - Sort: Descending
     - Limit: Top 10
  3. **Summary Table**:
     - Dimensions: `product_category_name_english`
     - Metrics:
       - Item Sales (`SUM(price)`)
       - Freight Total (`SUM(freight_value)`)
       - Orders (`COUNT_DISTINCT(order_id)`)
       - Items Sold (`COUNT(order_item_id)`)

---

### Page 3: Customer Segmentation
- **Primary Data Source**: `olist_gold.fact_orders` joined to `olist_gold.dim_customers` on `customer_key`
- **Visuals**:
  1. **Bar Chart (Revenue by State)**:
     - Dimension: `customer_state`
     - Metric: `SUM(payment_value)`
     - Sort: Descending
  2. **Bar Chart (Order Count by State)**:
     - Dimension: `customer_state`
     - Metric: `COUNT(order_id)`
     - Sort: Descending
  3. **Geo Map (Brazil)**:
     - Geo Dimension: `customer_state` (Brazil ISO region / State Code)
     - Metric: `SUM(payment_value)`
  4. **Bar Chart (Average Review Score by State)**:
     - Dimension: `customer_state`
     - Metric: `AVG(review_score)`
     - Sort: `AVG(review_score)` descending
