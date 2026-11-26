CREATE SCHEMA IF NOT EXISTS silver;

CREATE OR REPLACE TABLE silver.bridge_campaign_audience AS
SELECT DISTINCT
    TRIM(CAST(household_key AS VARCHAR)) AS household_key,
    TRIM(CAST(campaign AS VARCHAR)) AS campaign_id,
    COALESCE(NULLIF(TRIM(CAST(description AS VARCHAR)), ''), 'Unknown') AS campaign_type,
    CURRENT_TIMESTAMP AS _silver_created_at
FROM bronze.raw_campaign_audience
WHERE household_key IS NOT NULL
  AND campaign IS NOT NULL;