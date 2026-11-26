CREATE SCHEMA IF NOT EXISTS silver;

CREATE OR REPLACE TABLE silver.fact_coupon_redemption AS
WITH base AS (
    SELECT
        TRIM(CAST(household_key AS VARCHAR)) AS household_key,
        TRIM(CAST(coupon_upc AS VARCHAR)) AS coupon_upc,
        TRIM(CAST(campaign AS VARCHAR)) AS campaign_id,
        TRY_CAST(day AS INTEGER) AS day_num,
        ROW_NUMBER() OVER (
            PARTITION BY household_key, coupon_upc, campaign, day
            ORDER BY coupon_upc
        ) AS redemption_seq
    FROM bronze.raw_coupon_redempt
)
SELECT
    CONCAT_WS('_', household_key, coupon_upc, campaign_id, CAST(day_num AS VARCHAR), CAST(redemption_seq AS VARCHAR)) AS coupon_redemption_id,
    household_key,
    coupon_upc,
    campaign_id,
    day_num,
    CURRENT_TIMESTAMP AS _silver_created_at
FROM base;