-- Silver: geolocation. ~1M raw rows -> one row per zip prefix.
-- 1) keep only coordinates inside an approximate Brazil bounding box,
-- 2) average lat/lng per zip prefix,
-- 3) pick the MOST FREQUENT city/state per zip (deterministic; ANY_VALUE is deliberately not used).
CREATE OR REPLACE TABLE olist_silver.geolocation AS
WITH valid AS (
  SELECT
    LPAD(TRIM(geolocation_zip_code_prefix), 5, '0') AS zip_prefix,
    geolocation_lat AS lat,
    geolocation_lng AS lng,
    LOWER(TRIM(geolocation_city)) AS city,
    UPPER(TRIM(geolocation_state)) AS state
  FROM olist_bronze.geolocation
  WHERE geolocation_zip_code_prefix IS NOT NULL
    AND geolocation_lat BETWEEN -33.75 AND 5.30      -- approx. Brazil bounding box
    AND geolocation_lng BETWEEN -73.99 AND -34.79
),
coords AS (
  SELECT zip_prefix, AVG(lat) AS lat, AVG(lng) AS lng
  FROM valid
  GROUP BY zip_prefix
),
names AS (
  SELECT zip_prefix, city, state
  FROM valid
  GROUP BY zip_prefix, city, state
  QUALIFY ROW_NUMBER() OVER (PARTITION BY zip_prefix ORDER BY COUNT(*) DESC, city, state) = 1
)
SELECT zip_prefix, city, state, lat, lng
FROM coords
JOIN names USING (zip_prefix);
