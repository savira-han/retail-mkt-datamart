-- Gold Sales Fact Table: Daily Store-Level Sales Performance
-- Grain: (day_num, store_id)

CREATE SCHEMA IF NOT EXISTS gold;

CREATE OR REPLACE TABLE gold.fact_sales_daily AS
WITH txn_enriched AS (
    SELECT
        t.day_num,
        COALESCE(t.week_no, d.week_no) AS week_no,
        d.day_of_week_num,
        d.is_weekend_slot,
        t.store_id,
        t.basket_id,
        t.household_key,
        t.quantity,
        t.sales_value,
        t.retail_disc,
        t.coupon_disc,
        t.coupon_match_disc,
        t.gross_sales_value,
        t.net_paid_amount,
        t.is_return_or_void,
        t.is_zero_value
    FROM silver.fact_transaction t
    LEFT JOIN silver.dim_date d
        ON t.day_num = d.day_num
    WHERE t.day_num IS NOT NULL
      AND t.store_id IS NOT NULL
)

SELECT
    day_num,
    week_no,
    day_of_week_num,
    is_weekend_slot,
    store_id,
    COUNT(*) AS total_line_items,
    COUNT(DISTINCT basket_id) AS distinct_baskets,
    COUNT(DISTINCT household_key) AS distinct_households,
    COALESCE(SUM(quantity), 0) AS total_units,
    COALESCE(SUM(gross_sales_value), 0) AS gross_sales_value,
    COALESCE(SUM(sales_value), 0) AS sales_value,
    COALESCE(SUM(net_paid_amount), 0) AS net_paid_amount,
    COALESCE(SUM(ABS(COALESCE(retail_disc, 0))), 0) AS total_retail_disc_abs,
    COALESCE(SUM(ABS(COALESCE(coupon_disc, 0))), 0) AS total_coupon_disc_abs,
    COALESCE(SUM(ABS(COALESCE(coupon_match_disc, 0))), 0) AS total_coupon_match_disc_abs,
    SUM(CASE WHEN is_return_or_void THEN 1 ELSE 0 END) AS return_or_void_lines,
    SUM(CASE WHEN is_zero_value THEN 1 ELSE 0 END) AS zero_value_lines,
    CURRENT_TIMESTAMP AS _gold_created_at
FROM txn_enriched
GROUP BY
    day_num,
    week_no,
    day_of_week_num,
    is_weekend_slot,
    store_id
ORDER BY
    day_num,
    store_id;