-- Master Silver Layer Build Script
-- Executes all Silver dimensions, bridges, and facts in dependency order.

CREATE SCHEMA IF NOT EXISTS silver;

-- 1. dim_date
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

-- 2. dim_product
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

-- 3. dim_household
CREATE OR REPLACE TABLE silver.dim_household AS
WITH all_households AS (
    SELECT DISTINCT TRIM(CAST(household_key AS VARCHAR)) AS household_key
    FROM bronze.raw_transaction_data
    WHERE household_key IS NOT NULL

    UNION

    SELECT DISTINCT TRIM(CAST(household_key AS VARCHAR)) AS household_key
    FROM bronze.raw_campaign_audience
    WHERE household_key IS NOT NULL

    UNION

    SELECT DISTINCT TRIM(CAST(household_key AS VARCHAR)) AS household_key
    FROM bronze.raw_coupon_redempt
    WHERE household_key IS NOT NULL

    UNION

    SELECT DISTINCT TRIM(CAST(household_key AS VARCHAR)) AS household_key
    FROM bronze.raw_hh_demographic
    WHERE household_key IS NOT NULL
)
SELECT
    h.household_key,
    CASE WHEN d.household_key IS NOT NULL THEN TRUE ELSE FALSE END AS has_demographic_profile,
    COALESCE(NULLIF(TRIM(CAST(d.classification_1 AS VARCHAR)), ''), 'Unknown') AS classification_1,
    COALESCE(NULLIF(TRIM(CAST(d.classification_2 AS VARCHAR)), ''), 'Unknown') AS classification_2,
    COALESCE(NULLIF(TRIM(CAST(d.classification_3 AS VARCHAR)), ''), 'Unknown') AS classification_3,
    COALESCE(NULLIF(TRIM(CAST(d.classification_4 AS VARCHAR)), ''), 'Unknown') AS classification_4,
    COALESCE(NULLIF(TRIM(CAST(d.classification_5 AS VARCHAR)), ''), 'Unknown') AS classification_5,
    COALESCE(NULLIF(TRIM(CAST(d.homeowner_desc AS VARCHAR)), ''), 'Unknown') AS homeowner_desc,
    COALESCE(NULLIF(TRIM(CAST(d.kid_category_desc AS VARCHAR)), ''), 'Unknown') AS kid_category_desc,
    CURRENT_TIMESTAMP AS _silver_created_at
FROM all_households h
LEFT JOIN bronze.raw_hh_demographic d
    ON h.household_key = TRIM(CAST(d.household_key AS VARCHAR))
WHERE h.household_key <> '';

-- 4. dim_campaign
CREATE OR REPLACE TABLE silver.dim_campaign AS
SELECT
    TRIM(CAST(campaign AS VARCHAR)) AS campaign_id,
    COALESCE(NULLIF(TRIM(CAST(description AS VARCHAR)), ''), 'Unknown') AS campaign_type,
    TRY_CAST(start_day AS INTEGER) AS start_day,
    TRY_CAST(end_day AS INTEGER) AS end_day,
    (TRY_CAST(end_day AS INTEGER) - TRY_CAST(start_day AS INTEGER) + 1) AS duration_days,
    CURRENT_TIMESTAMP AS _silver_created_at
FROM bronze.raw_campaign_desc
WHERE campaign IS NOT NULL
  AND TRIM(CAST(campaign AS VARCHAR)) <> '';

-- 5. dim_store
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

-- 6. bridge_campaign_audience
CREATE OR REPLACE TABLE silver.bridge_campaign_audience AS
SELECT DISTINCT
    TRIM(CAST(household_key AS VARCHAR)) AS household_key,
    TRIM(CAST(campaign AS VARCHAR)) AS campaign_id,
    COALESCE(NULLIF(TRIM(CAST(description AS VARCHAR)), ''), 'Unknown') AS campaign_type,
    CURRENT_TIMESTAMP AS _silver_created_at
FROM bronze.raw_campaign_audience
WHERE household_key IS NOT NULL
  AND campaign IS NOT NULL;

-- 7. bridge_coupon_product
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

-- 8. fact_transaction
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
    (sales_value - COALESCE(retail_disc, 0) - COALESCE(coupon_match_disc, 0)) AS gross_sales_value,
    (sales_value + COALESCE(coupon_disc, 0)) AS net_paid_amount,
    CASE WHEN quantity < 0 OR sales_value < 0 THEN TRUE ELSE FALSE END AS is_return_or_void,
    CASE WHEN quantity = 0 OR sales_value = 0 THEN TRUE ELSE FALSE END AS is_zero_value,
    CURRENT_TIMESTAMP AS _silver_created_at
FROM base;

-- 9. fact_coupon_redemption
CREATE OR REPLACE TABLE silver.fact_coupon_redemption AS
WITH base AS (
    SELECT
        TRIM(CAST(household_key AS VARCHAR)) AS household_key,
        TRIM(CAST(coupon_upc AS VARCHAR)) AS coupon_upc,
        TRIM(CAST(campaign AS VARCHAR)) AS campaign_id,
        TRY_CAST(day AS INTEGER) AS day_num,
        ROW_NUMBER() OVER (
            PARTITION BY household_key, coupon_upc, campaign, day
            ORDER BY coupon_upc
        ) AS redemption_seq
    FROM bronze.raw_coupon_redempt
)
SELECT
    CONCAT_WS('_', household_key, coupon_upc, campaign_id, CAST(day_num AS VARCHAR), CAST(redemption_seq AS VARCHAR)) AS coupon_redemption_id,
    household_key,
    coupon_upc,
    campaign_id,
    day_num,
    CURRENT_TIMESTAMP AS _silver_created_at
FROM base;

-- 10. fact_store_promo_placement
CREATE OR REPLACE TABLE silver.fact_store_promo_placement AS
WITH cleaned AS (
    SELECT
        TRIM(CAST(store_id AS VARCHAR)) AS store_id,
        TRIM(CAST(product_id AS VARCHAR)) AS product_id,
        TRY_CAST(week_no AS INTEGER) AS week_no,
        COALESCE(NULLIF(TRIM(CAST(display AS VARCHAR)), ''), '0') AS display_code,
        COALESCE(NULLIF(TRIM(CAST(mailer AS VARCHAR)), ''), '0') AS mailer_code
    FROM bronze.raw_store_promo_placement
    WHERE store_id IS NOT NULL
      AND product_id IS NOT NULL
      AND week_no IS NOT NULL
),
deduped AS (
    SELECT
        store_id,
        product_id,
        week_no,
        MAX(display_code) AS display_code,
        MAX(mailer_code) AS mailer_code
    FROM cleaned
    GROUP BY store_id, product_id, week_no
)
SELECT
    store_id,
    product_id,
    week_no,
    display_code,
    mailer_code,
    CASE WHEN display_code <> '0' THEN TRUE ELSE FALSE END AS is_on_display,
    CASE WHEN mailer_code <> '0' THEN TRUE ELSE FALSE END AS is_in_mailer,
    CURRENT_TIMESTAMP AS _silver_created_at
FROM deduped;