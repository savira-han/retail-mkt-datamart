CREATE SCHEMA IF NOT EXISTS silver;

CREATE OR REPLACE TABLE silver.dim_product AS
SELECT
    TRIM(CAST(product_id AS VARCHAR)) AS product_id,
    NULLIF(TRIM(CAST(manufacturer AS VARCHAR)), '') AS manufacturer,
    COALESCE(NULLIF(TRIM(CAST(department AS VARCHAR)), ''), 'Unknown') AS department,
    COALESCE(NULLIF(TRIM(CAST(brand AS VARCHAR)), ''), 'Unknown') AS brand,
    COALESCE(NULLIF(TRIM(CAST(commodity_desc AS VARCHAR)), ''), 'Unknown') AS commodity_desc,
    COALESCE(NULLIF(TRIM(CAST(sub_commodity_desc AS VARCHAR)), ''), 'Unknown') AS sub_commodity_desc,
    NULLIF(TRIM(CAST(curr_size_of_product AS VARCHAR)), '') AS curr_size_of_product,
    CURRENT_TIMESTAMP AS _silver_created_at
FROM bronze.raw_product_inventory
WHERE product_id IS NOT NULL
  AND TRIM(CAST(product_id AS VARCHAR)) <> '';