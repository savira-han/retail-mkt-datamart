-- Gold Weekly Sales Aggregation: Weekly Store-Level Sales & Shopper Metrics
-- Grain: (week_no, store_id)

CREATE SCHEMA IF NOT EXISTS gold;

CREATE OR REPLACE TABLE gold.agg_sales_weekly AS
WITH txn_weekly AS (
    SELECT
        COALESCE(t.week_no, d.week_no) AS week_no,
        t.day_num,
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
    WHERE COALESCE(t.week_no, d.week_no) IS NOT NULL
      AND t.store_id IS NOT NULL
)
SELECT
    week_no,
    store_id,
    MIN(day_num) AS week_start_day,
    MAX(day_num) AS week_end_day,
    COUNT(DISTINCT day_num) AS active_days_in_week,
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
    ROUND(
        CASE WHEN COUNT(DISTINCT basket_id) > 0
             THEN SUM(sales_value) / COUNT(DISTINCT basket_id)
             ELSE 0
        END,
        2
    ) AS avg_basket_value,
    ROUND(
        CASE WHEN COUNT(DISTINCT household_key) > 0
             THEN SUM(sales_value) / COUNT(DISTINCT household_key)
             ELSE 0
        END,
        2
    ) AS avg_spend_per_household,
    SUM(CASE WHEN is_return_or_void THEN 1 ELSE 0 END) AS return_or_void_lines,
    SUM(CASE WHEN is_zero_value THEN 1 ELSE 0 END) AS zero_value_lines,
    CURRENT_TIMESTAMP AS _gold_created_at
FROM txn_weekly
GROUP BY
    week_no,
    store_id
ORDER BY
    week_no,
    store_id;