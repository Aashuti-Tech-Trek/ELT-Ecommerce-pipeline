-- Gold: geolocation dimension (one row per 5-digit zip prefix).
CREATE OR REPLACE TABLE olist_gold.dim_geolocation AS
SELECT
  zip_prefix,
  city,
  state,
  lat,
  lng
FROM olist_silver.geolocation;
