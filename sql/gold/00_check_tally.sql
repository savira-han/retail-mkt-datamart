-- -- check fact 01
-- SELECT
--     (SELECT CAST(SUM(sales_value) AS FLOAT) FROM silver.fact_transaction) AS silver_sales_value,
--     (SELECT SUM(sales_value) FROM gold.fact_sales_daily) AS gold_sales_value,
--     (SELECT COUNT(*) FROM gold.fact_sales_daily) AS daily_store_rows,

-- -- check fact 02
-- SELECT
--     promo_channel,
--     COUNT(*) AS store_product_weeks,
--     SUM(total_units) AS total_units,
--     ROUND(SUM(sales_value), 2) AS total_sales_value,
--     ROUND(AVG(sales_value), 2) AS avg_weekly_sales_per_sku_store
-- FROM gold.fact_product_promo_weekly
-- GROUP BY promo_channel
-- ORDER BY total_sales_value DESC;

-- -- check agg 03
-- SELECT
--     (SELECT ROUND(SUM(sales_value), 2) FROM gold.fact_sales_daily) AS daily_sales_total,
--     (SELECT ROUND(SUM(sales_value), 2) FROM gold.agg_sales_weekly) AS weekly_sales_total,
--     (SELECT COUNT(*) FROM gold.agg_sales_weekly) AS weekly_store_rows,
--     (SELECT COUNT(DISTINCT week_no) FROM gold.agg_sales_weekly) AS distinct_weeks;

-- -- check fact 04
-- SELECT
--     campaign_type,
--     COUNT(*) AS campaigns,
--     SUM(targeted_households) AS total_targeted_hh,
--     SUM(active_shoppers_in_window) AS total_active_shoppers,
--     SUM(redeeming_households) AS total_redeemers,
--     ROUND(AVG(visit_rate_pct), 2) AS avg_visit_rate_pct,
--     ROUND(AVG(redemption_rate_pct), 2) AS avg_redemption_rate_pct,
--     ROUND(SUM(window_sales_value), 2) AS total_window_sales,
--     ROUND(SUM(eligible_product_sales_value), 2) AS total_eligible_sku_sales
-- FROM gold.fact_campaign_funnel
-- GROUP BY campaign_type
-- ORDER BY campaign_type;

-- check size table
-- SELECT
--     table_name,
--     estimated_size AS row_count,
--     ROUND(
--         estimated_size * 1.0,
--         2
--     ) AS estimated_rows
-- FROM duckdb_tables()
-- where SCHEMA = 
-- ORDER BY table_name;


SELECT
    table_name,
    table_type,
    ROUND(size_bytes / 1024.0 / 1024.0, 2) AS estimated_size_mb
FROM (
    SELECT
        table_name,
        table_type,
        SUM(compressed_size) AS size_bytes
    FROM pragma_storage_info('gold')
    GROUP BY table_name
) s
JOIN information_schema.tables t
    USING (table_name)
WHERE t.table_schema = 'gold'
ORDER BY table_name;