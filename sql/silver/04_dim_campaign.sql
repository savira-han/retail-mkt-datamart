CREATE SCHEMA IF NOT EXISTS silver;

CREATE OR REPLACE TABLE silver.dim_campaign AS
SELECT
    TRIM(CAST(campaign AS VARCHAR)) AS campaign_id,
    COALESCE(NULLIF(TRIM(CAST(description AS VARCHAR)), ''), 'Unknown') AS campaign_type,
    TRY_CAST(start_day AS INTEGER) AS start_day,
    TRY_CAST(end_day AS INTEGER) AS end_day,
    (TRY_CAST(end_day AS INTEGER) - TRY_CAST(start_day AS INTEGER) + 1) AS duration_days,
    CURRENT_TIMESTAMP AS _silver_created_at
FROM bronze.raw_campaign_desc
WHERE campaign IS NOT NULL
  AND TRIM(CAST(campaign AS VARCHAR)) <> '';