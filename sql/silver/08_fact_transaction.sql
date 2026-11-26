CREATE SCHEMA IF NOT EXISTS silver;

CREATE OR REPLACE TABLE silver.fact_transaction AS
WITH base AS (
    SELECT
        TRIM(CAST(basket_id AS VARCHAR)) AS basket_id,
        TRIM(CAST(household_key AS VARCHAR)) AS household_key,
        TRIM(CAST(product_id AS VARCHAR)) AS product_id,
        TRIM(CAST(store_id AS VARCHAR)) AS store_id,
        TRY_CAST(day AS INTEGER) AS day_num,
        TRY_CAST(week_no AS INTEGER) AS week_no,
        TRY_CAST(trans_time AS INTEGER) AS trans_time,
        TRY_CAST(quantity AS DOUBLE) AS quantity,
        TRY_CAST(sales_value AS DOUBLE) AS sales_value,
        TRY_CAST(retail_disc AS DOUBLE) AS retail_disc,
        TRY_CAST(coupon_disc AS DOUBLE) AS coupon_disc,
        TRY_CAST(coupon_match_disc AS DOUBLE) AS coupon_match_disc,
        ROW_NUMBER() OVER (
            PARTITION BY basket_id, product_id, trans_time
            ORDER BY sales_value, quantity
        ) AS line_seq
    FROM bronze.raw_transaction_data
)
SELECT
    CONCAT_WS('_', basket_id, product_id, CAST(trans_time AS VARCHAR), CAST(line_seq AS VARCHAR)) AS order_detail_id,
    basket_id,
    household_key,
    product_id,
    store_id,
    day_num,
    week_no,
    trans_time,
    (trans_time // 100) AS trans_hour,
    CASE
        WHEN (trans_time // 100) BETWEEN 5 AND 11 THEN 'Morning'
        WHEN (trans_time // 100) BETWEEN 12 AND 16 THEN 'Afternoon'
        WHEN (trans_time // 100) BETWEEN 17 AND 21 THEN 'Evening'
        ELSE 'Night'
    END AS time_of_day_bucket,
    quantity,
    sales_value,
    retail_disc,
    coupon_disc,
    coupon_match_disc,
    -- dunnhumby discount columns are negative/zero; sales_value already deducts retail_disc & coupon_match_disc
    (sales_value - COALESCE(retail_disc, 0) - COALESCE(coupon_match_disc, 0)) AS gross_sales_value,
    (sales_value + COALESCE(coupon_disc, 0)) AS net_paid_amount,
    CASE WHEN quantity < 0 OR sales_value < 0 THEN TRUE ELSE FALSE END AS is_return_or_void,
    CASE WHEN quantity = 0 OR sales_value = 0 THEN TRUE ELSE FALSE END AS is_zero_value,
    CURRENT_TIMESTAMP AS _silver_created_at
FROM base;