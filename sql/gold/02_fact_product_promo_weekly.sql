-- Gold Product & Promo Fact Table: Weekly Store-Product Sales & Promotional Lift
-- Grain: (week_no, store_id, product_id)

CREATE SCHEMA IF NOT EXISTS gold;

CREATE OR REPLACE TABLE gold.fact_product_promo_weekly AS
WITH weekly_product_sales AS (
    SELECT
        COALESCE(t.week_no, d.week_no) AS week_no,
        t.store_id,
        t.product_id,
        COUNT(*) AS total_line_items,
        COUNT(DISTINCT t.basket_id) AS distinct_baskets,
        COUNT(DISTINCT t.household_key) AS distinct_households,
        COALESCE(SUM(t.quantity), 0) AS total_units,
        COALESCE(SUM(t.gross_sales_value), 0) AS gross_sales_value,
        COALESCE(SUM(t.sales_value), 0) AS sales_value,
        COALESCE(SUM(t.net_paid_amount), 0) AS net_paid_amount,
        COALESCE(SUM(ABS(COALESCE(t.retail_disc, 0))), 0) AS total_retail_disc_abs,
        COALESCE(SUM(ABS(COALESCE(t.coupon_disc, 0))), 0) AS total_coupon_disc_abs,
        COALESCE(SUM(ABS(COALESCE(t.coupon_match_disc, 0))), 0) AS total_coupon_match_disc_abs
    FROM silver.fact_transaction t
    LEFT JOIN silver.dim_date d
        ON t.day_num = d.day_num
    WHERE t.store_id IS NOT NULL
      AND t.product_id IS NOT NULL
      AND COALESCE(t.week_no, d.week_no) IS NOT NULL
    GROUP BY
        COALESCE(t.week_no, d.week_no),
        t.store_id,
        t.product_id
)
SELECT
    s.week_no,
    s.store_id,
    s.product_id,
    COALESCE(p.department, 'Unknown') AS department,
    COALESCE(p.commodity_desc, 'Unknown') AS commodity_desc,
    COALESCE(p.sub_commodity_desc, 'Unknown') AS sub_commodity_desc,
    COALESCE(p.brand, 'Unknown') AS brand,
    p.manufacturer,
    COALESCE(pr.display_code, '0') AS display_code,
    COALESCE(pr.mailer_code, '0') AS mailer_code,
    COALESCE(pr.is_on_display, FALSE) AS is_on_display,
    COALESCE(pr.is_in_mailer, FALSE) AS is_in_mailer,
    CASE
        WHEN COALESCE(pr.is_on_display, FALSE) AND COALESCE(pr.is_in_mailer, FALSE) THEN 'Display + Mailer'
        WHEN COALESCE(pr.is_on_display, FALSE) THEN 'Display Only'
        WHEN COALESCE(pr.is_in_mailer, FALSE) THEN 'Mailer Only'
        ELSE 'No Promo'
    END AS promo_channel,
    s.total_line_items,
    s.distinct_baskets,
    s.distinct_households,
    s.total_units,
    s.gross_sales_value,
    s.sales_value,
    s.net_paid_amount,
    s.total_retail_disc_abs,
    s.total_coupon_disc_abs,
    s.total_coupon_match_disc_abs,
    CURRENT_TIMESTAMP AS _gold_created_at
FROM weekly_product_sales s
LEFT JOIN silver.fact_store_promo_placement pr
    ON s.week_no = pr.week_no
   AND s.store_id = pr.store_id
   AND s.product_id = pr.product_id
LEFT JOIN silver.dim_product p
    ON s.product_id = p.product_id
ORDER BY
    s.week_no,
    s.store_id,
    s.product_id;