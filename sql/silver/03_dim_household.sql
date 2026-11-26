CREATE SCHEMA IF NOT EXISTS silver;

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