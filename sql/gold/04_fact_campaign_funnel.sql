-- Gold Campaign Funnel Fact Table: End-to-End Campaign Conversion & Spend
-- Grain: campaign_id

CREATE SCHEMA IF NOT EXISTS gold;

CREATE OR REPLACE TABLE gold.fact_campaign_funnel AS
WITH campaign_audience AS (
    SELECT
        b.campaign_id,
        COUNT(DISTINCT b.household_key) AS targeted_households,
        COUNT(DISTINCT CASE WHEN h.has_demographic_profile THEN b.household_key END) AS targeted_households_with_demo
    FROM silver.bridge_campaign_audience b
    LEFT JOIN silver.dim_household h
        ON b.household_key = h.household_key
    GROUP BY b.campaign_id
),
campaign_coupon_scope AS (
    SELECT
        campaign_id,
        COUNT(DISTINCT coupon_upc) AS eligible_coupons,
        COUNT(DISTINCT product_id) AS eligible_products
    FROM silver.bridge_coupon_product
    GROUP BY campaign_id
),
campaign_redemptions AS (
    SELECT
        r.campaign_id,
        COUNT(*) AS total_redemption_events,
        COUNT(DISTINCT r.household_key) AS redeeming_households,
        COUNT(DISTINCT r.coupon_upc) AS redeemed_distinct_coupons,
        COUNT(DISTINCT CASE
            WHEN r.day_num BETWEEN c.start_day AND c.end_day THEN r.household_key
        END) AS redeeming_households_in_window,
        SUM(CASE
            WHEN r.day_num BETWEEN c.start_day AND c.end_day THEN 1 ELSE 0
        END) AS in_window_redemption_events
    FROM silver.fact_coupon_redemption r
    INNER JOIN silver.dim_campaign c
        ON r.campaign_id = c.campaign_id
    GROUP BY r.campaign_id
),
campaign_window_sales AS (
    SELECT
        c.campaign_id,
        COUNT(DISTINCT t.household_key) AS active_shoppers_in_window,
        COUNT(DISTINCT t.basket_id) AS window_baskets,
        COALESCE(SUM(t.quantity), 0) AS window_units,
        COALESCE(SUM(t.gross_sales_value), 0) AS window_gross_sales_value,
        COALESCE(SUM(t.sales_value), 0) AS window_sales_value,
        COALESCE(SUM(t.net_paid_amount), 0) AS window_net_paid_amount,
        COALESCE(SUM(ABS(COALESCE(t.coupon_disc, 0))), 0) AS window_coupon_disc_abs,
        COALESCE(SUM(ABS(COALESCE(t.coupon_match_disc, 0))), 0) AS window_coupon_match_disc_abs
    FROM silver.dim_campaign c
    INNER JOIN silver.bridge_campaign_audience b
        ON c.campaign_id = b.campaign_id
    INNER JOIN silver.fact_transaction t
        ON b.household_key = t.household_key
       AND t.day_num BETWEEN c.start_day AND c.end_day
    GROUP BY c.campaign_id
),
campaign_eligible_product_sales AS (
    SELECT
        c.campaign_id,
        COUNT(DISTINCT t.household_key) AS eligible_product_buyers,
        COALESCE(SUM(t.quantity), 0) AS eligible_product_units,
        COALESCE(SUM(t.sales_value), 0) AS eligible_product_sales_value
    FROM silver.dim_campaign c
    INNER JOIN silver.bridge_campaign_audience b
        ON c.campaign_id = b.campaign_id
    INNER JOIN (
        SELECT DISTINCT campaign_id, product_id
        FROM silver.bridge_coupon_product
    ) cp
        ON c.campaign_id = cp.campaign_id
    INNER JOIN silver.fact_transaction t
        ON b.household_key = t.household_key
       AND cp.product_id = t.product_id
       AND t.day_num BETWEEN c.start_day AND c.end_day
    GROUP BY c.campaign_id
)
SELECT
    c.campaign_id,
    c.campaign_type,
    c.start_day,
    c.end_day,
    c.duration_days,
    COALESCE(cs.eligible_coupons, 0) AS eligible_coupons,
    COALESCE(cs.eligible_products, 0) AS eligible_products,
    COALESCE(ca.targeted_households, 0) AS targeted_households,
    COALESCE(ca.targeted_households_with_demo, 0) AS targeted_households_with_demo,
    COALESCE(ws.active_shoppers_in_window, 0) AS active_shoppers_in_window,
    COALESCE(cr.redeeming_households, 0) AS redeeming_households,
    COALESCE(cr.redeeming_households_in_window, 0) AS redeeming_households_in_window,
    COALESCE(cr.total_redemption_events, 0) AS total_redemption_events,
    COALESCE(cr.in_window_redemption_events, 0) AS in_window_redemption_events,
    COALESCE(cr.redeemed_distinct_coupons, 0) AS redeemed_distinct_coupons,
    ROUND(
        CASE WHEN COALESCE(ca.targeted_households, 0) > 0
             THEN 100.0 * COALESCE(ws.active_shoppers_in_window, 0) / ca.targeted_households
             ELSE 0
        END,
        2
    ) AS visit_rate_pct,
    ROUND(
        CASE WHEN COALESCE(ca.targeted_households, 0) > 0
             THEN 100.0 * COALESCE(cr.redeeming_households, 0) / ca.targeted_households
             ELSE 0
        END,
        2
    ) AS redemption_rate_pct,
    ROUND(
        CASE WHEN COALESCE(ws.active_shoppers_in_window, 0) > 0
             THEN 100.0 * COALESCE(cr.redeeming_households, 0) / ws.active_shoppers_in_window
             ELSE 0
        END,
        2
    ) AS active_shopper_redemption_rate_pct,
    COALESCE(ws.window_baskets, 0) AS window_baskets,
    COALESCE(ws.window_units, 0) AS window_units,
    COALESCE(ws.window_gross_sales_value, 0) AS window_gross_sales_value,
    COALESCE(ws.window_sales_value, 0) AS window_sales_value,
    COALESCE(ws.window_net_paid_amount, 0) AS window_net_paid_amount,
    COALESCE(ws.window_coupon_disc_abs, 0) AS window_coupon_disc_abs,
    COALESCE(ws.window_coupon_match_disc_abs, 0) AS window_coupon_match_disc_abs,
    COALESCE(eps.eligible_product_buyers, 0) AS eligible_product_buyers,
    COALESCE(eps.eligible_product_units, 0) AS eligible_product_units,
    COALESCE(eps.eligible_product_sales_value, 0) AS eligible_product_sales_value,
    ROUND(
        CASE WHEN COALESCE(ca.targeted_households, 0) > 0
             THEN COALESCE(ws.window_sales_value, 0) / ca.targeted_households
             ELSE 0
        END,
        2
    ) AS sales_per_targeted_household,
    CURRENT_TIMESTAMP AS _gold_created_at
FROM silver.dim_campaign c
LEFT JOIN campaign_audience ca
    ON c.campaign_id = ca.campaign_id
LEFT JOIN campaign_coupon_scope cs
    ON c.campaign_id = cs.campaign_id
LEFT JOIN campaign_redemptions cr
    ON c.campaign_id = cr.campaign_id
LEFT JOIN campaign_window_sales ws
    ON c.campaign_id = ws.campaign_id
LEFT JOIN campaign_eligible_product_sales eps
    ON c.campaign_id = eps.campaign_id
ORDER BY
    c.start_day,
    c.campaign_id;