CREATE SCHEMA IF NOT EXISTS silver;

CREATE OR REPLACE TABLE silver.bridge_coupon_product AS
SELECT DISTINCT
    TRIM(CAST(coupon_upc AS VARCHAR)) AS coupon_upc,
    TRIM(CAST(product_id AS VARCHAR)) AS product_id,
    TRIM(CAST(campaign AS VARCHAR)) AS campaign_id,
    CURRENT_TIMESTAMP AS _silver_created_at
FROM bronze.raw_coupon_inventory
WHERE coupon_upc IS NOT NULL
  AND product_id IS NOT NULL
  AND campaign IS NOT NULL;