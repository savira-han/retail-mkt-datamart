CREATE SCHEMA IF NOT EXISTS silver;

CREATE OR REPLACE TABLE silver.dim_date AS
WITH all_days AS (
    SELECT DISTINCT TRY_CAST(day AS INTEGER) AS day_num
    FROM bronze.raw_transaction_data
    WHERE TRY_CAST(day AS INTEGER) IS NOT NULL

    UNION

    SELECT DISTINCT TRY_CAST(day AS INTEGER) AS day_num
    FROM bronze.raw_coupon_redempt
    WHERE TRY_CAST(day AS INTEGER) IS NOT NULL

    UNION

    SELECT DISTINCT TRY_CAST(start_day AS INTEGER) AS day_num
    FROM bronze.raw_campaign_desc
    WHERE TRY_CAST(start_day AS INTEGER) IS NOT NULL

    UNION

    SELECT DISTINCT TRY_CAST(end_day AS INTEGER) AS day_num
    FROM bronze.raw_campaign_desc
    WHERE TRY_CAST(end_day AS INTEGER) IS NOT NULL
),
bounds AS (
    SELECT
        MIN(day_num) AS min_day,
        MAX(day_num) AS max_day
    FROM all_days
),
day_spine AS (
    SELECT CAST(gs.day_num AS INTEGER) AS day_num
    FROM bounds
    CROSS JOIN GENERATE_SERIES(bounds.min_day, bounds.max_day, 1) AS gs(day_num)
),
txn_day_week AS (
    SELECT DISTINCT
        TRY_CAST(day AS INTEGER) AS day_num,
        TRY_CAST(week_no AS INTEGER) AS txn_week_no
    FROM bronze.raw_transaction_data
    WHERE TRY_CAST(day AS INTEGER) IS NOT NULL
      AND TRY_CAST(week_no AS INTEGER) IS NOT NULL
)
SELECT
    s.day_num,
    COALESCE(t.txn_week_no, ((s.day_num - 1) // 7) + 1) AS week_no,
    ((s.day_num - 1) % 7) + 1 AS day_of_week_num,
    CASE WHEN ((s.day_num - 1) % 7) + 1 IN (6, 7) THEN TRUE ELSE FALSE END AS is_weekend_slot,
    CURRENT_TIMESTAMP AS _silver_created_at
FROM day_spine s
LEFT JOIN txn_day_week t
    ON s.day_num = t.day_num
ORDER BY s.day_num;