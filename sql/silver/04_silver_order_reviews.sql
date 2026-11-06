-- Silver: reviews. Source has several reviews per order; keep ONE per order_id (the latest answered).
CREATE OR REPLACE TABLE olist_silver.order_reviews AS
SELECT
  TRIM(review_id) AS review_id,
  TRIM(order_id) AS order_id,
  CAST(review_score AS INT64) AS review_score,
  review_comment_title,
  review_comment_message,
  CAST(review_creation_date AS TIMESTAMP) AS review_creation_ts,
  CAST(review_answer_timestamp AS TIMESTAMP) AS review_answer_ts
FROM olist_bronze.order_reviews
WHERE order_id IS NOT NULL
  AND review_score BETWEEN 1 AND 5
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY TRIM(order_id)
  ORDER BY review_answer_timestamp DESC, review_creation_date DESC, review_id DESC
) = 1;
