CREATE SCHEMA IF NOT EXISTS silver;

CREATE OR REPLACE TABLE silver.dim_store AS
WITH all_stores AS (
    SELECT DISTINCT TRIM(CAST(store_id AS VARCHAR)) AS store_id
    FROM bronze.raw_transaction_data
    WHERE store_id IS NOT NULL

    UNION

    SELECT DISTINCT TRIM(CAST(store_id AS VARCHAR)) AS store_id
    FROM bronze.raw_store_promo_placement
    WHERE store_id IS NOT NULL
)
SELECT
    store_id,
    CURRENT_TIMESTAMP AS _silver_created_at
FROM all_stores
WHERE store_id <> '';