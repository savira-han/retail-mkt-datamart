# Gold Layer Datamart Reference

## Overview

The `gold` schema in `retailmkt.db` holds four curated analytical tables built for reporting, dashboarding, and ad hoc analysis. Each table is shaped around a single grain so you can query daily sales, weekly store trends, promotional lift, or campaign conversions without reconstructing complex joins or risking double counting.

| Schema | Table Name | Table Type | Analytical Grain | Row Count |
| :--- | :--- | :--- | :--- | :--- |
| `gold` | `fact_sales_daily` | `BASE TABLE` | `day_num`, `store_id` | `71,569` |
| `gold` | `agg_sales_weekly` | `BASE TABLE` | `week_no`, `store_id` | `13,939` |
| `gold` | `fact_product_promo_weekly` | `BASE TABLE` | `week_no`, `store_id`, `product_id` | `2,370,784` |
| `gold` | `fact_campaign_funnel` | `BASE TABLE` | `campaign_id` | `30` |

## Data Lineage and Origin

All records originate from the dunnhumby The Complete Journey retail dataset, within 711 operational days (102 retail weeks) of household baskets, store transactions, promotional placements, and marketing campaigns.

The warehouse moves through three layers:

1. **Bronze (`bronze.*`):** Raw source data loaded with standardized column names and explicit string identifiers (`raw_transaction_data`, `raw_store_promo_placement`, `raw_campaign_desc`, `raw_campaign_audience`, `raw_coupon_inventory`, `raw_coupon_redempt`, `raw_product_inventory`, and `raw_hh_demographic`).
2. **Silver (`silver.*`):** Cleaned and conformed dimensional models (`fact_transaction`, `fact_store_promo_placement`, `fact_coupon_redemption`, `dim_date`, `dim_product`, `dim_household`, `dim_campaign`, `bridge_campaign_audience`, and `bridge_coupon_product`) with standardized keys, dates, and boolean flags.
3. **Gold (`gold.*`):** Analytical marts built strictly from `silver.*` tables. Gold transformations never query `bronze.*` directly.

## Architecture Purpose and Design Principles

* **Silver to Gold Isolation:** Every Gold model reads exclusively from conformed Silver tables, ensuring all business logic, type casting, and key cleaning happen once upstream.
* **Grain First Modeling:** Facts are aggregated to their target analytical grain before joining across domains so many to many relationships never inflate totals.
* **Exact Weekly Distinct Counts:** Weekly unique shoppers and baskets in `agg_sales_weekly` are computed natively at the `(week_no, store_id)` level from `silver.fact_transaction` rather than summing daily distinct counts, preventing multi day visitors from being counted twice within the same week.
* **Consistent Financial Definitions:**
  * `gross_sales_value`: Full shelf value prior to retail markdowns and manufacturer coupon match discounts.
  * `sales_value`: Net retailer revenue after retail markdowns and coupon match discounts. Total `sales_value` reconciles to `$8,057,463.08` across all sales and product tables.
  * `net_paid_amount`: Out of pocket amount paid by shoppers after coupon discounts are applied.
  * Return or void rows (`is_return_or_void`) and zero value rows (`is_zero_value`) remain in net revenue totals so financial numbers match source records, with separate line count columns included for auditing.

## Choosing the Right Table

* **`gold.fact_sales_daily`:** Daily store revenue, weekday versus weekend shopping patterns, and daily discount depth.
* **`gold.agg_sales_weekly`:** Weekly store rollups, week over week trends, average basket value, and average weekly spend per household.
* **`gold.fact_product_promo_weekly`:** Weekly SKU velocity by store and promotional lift across store displays and weekly circular mailers.
* **`gold.fact_campaign_funnel`:** Campaign conversion tracking from targeted households to window shoppers, coupon redeemers, and eligible product sales.

## Table Specifications

### 1. `gold.fact_sales_daily`

* **Lineage:** Built by joining `silver.fact_transaction` with `silver.dim_date` on `day_num` (`sql/gold/01_fact_sales_daily.sql`). Traces back to `bronze.raw_transaction_data`.
* **Grain:** One row per `day_num` and `store_id` (`71,569` rows across 711 days).
* **Usage Notes:** Additive amounts (`sales_value`, `gross_sales_value`, `net_paid_amount`, `total_units`, and discount sums) roll up cleanly across days or stores. Do not sum `distinct_baskets` or `distinct_households` across multiple days to get multi day unique counts.

| Column Name | Data Type | Description |
| :--- | :--- | :--- |
| `day_num` | `INTEGER` | Sequential day index from 1 to 711 (primary key part 1) |
| `week_no` | `INTEGER` | Retail week number from 1 to 102 |
| `day_of_week_num` | `INTEGER` | Day index from 1 to 7 within the retail week |
| `is_weekend_slot` | `BOOLEAN` | True when `day_of_week_num` is 6 or 7 |
| `store_id` | `VARCHAR` | Store identifier (primary key part 2) |
| `total_line_items` | `BIGINT` | Total transaction rows recorded on that store day |
| `distinct_baskets` | `BIGINT` | Unique `basket_id` count on that store day |
| `distinct_households` | `BIGINT` | Unique `household_key` count on that store day |
| `total_units` | `DOUBLE` | Total item quantity sold |
| `gross_sales_value` | `DOUBLE` | Pre discount shelf value |
| `sales_value` | `DOUBLE` | Net retailer sales revenue |
| `net_paid_amount` | `DOUBLE` | Shopper spend after coupon discounts |
| `total_retail_disc_abs` | `DOUBLE` | Positive sum of retail store markdowns |
| `total_coupon_disc_abs` | `DOUBLE` | Positive sum of shopper coupon discounts |
| `total_coupon_match_disc_abs` | `DOUBLE` | Positive sum of manufacturer coupon match discounts |
| `return_or_void_lines` | `BIGINT` | Count of line items marked as returns or voids |
| `zero_value_lines` | `BIGINT` | Count of line items with zero sales value |
| `_gold_created_at` | `TIMESTAMP` | Build timestamp |

### 2. `gold.agg_sales_weekly`

* **Lineage:** Built directly from `silver.fact_transaction` joined to `silver.dim_date` on `day_num` and grouped by `week_no` and `store_id` (`sql/gold/03_agg_sales_weekly.sql`). Traces back to `bronze.raw_transaction_data`.
* **Grain:** One row per `week_no` and `store_id` (`13,939` rows across 102 weeks).
* **Usage Notes:** Use this table for weekly store reporting and shopper ratios (`avg_basket_value`, `avg_spend_per_household`). Check `active_days_in_week` when comparing boundary weeks at the start or end of the dataset, as values below 7 indicate partial weeks.

| Column Name | Data Type | Description |
| :--- | :--- | :--- |
| `week_no` | `INTEGER` | Retail week number from 1 to 102 (primary key part 1) |
| `store_id` | `VARCHAR` | Store identifier (primary key part 2) |
| `week_start_day` | `INTEGER` | Earliest `day_num` observed in that store week |
| `week_end_day` | `INTEGER` | Latest `day_num` observed in that store week |
| `active_days_in_week` | `BIGINT` | Count of distinct active days in that store week |
| `total_line_items` | `BIGINT` | Total transaction lines in that store week |
| `distinct_baskets` | `BIGINT` | Exact count of unique baskets in that store week |
| `distinct_households` | `BIGINT` | Exact count of unique households shopping in that store week |
| `total_units` | `DOUBLE` | Total units sold in that store week |
| `gross_sales_value` | `DOUBLE` | Weekly shelf value before retail markdowns and coupon match discounts |
| `sales_value` | `DOUBLE` | Weekly net retailer sales revenue |
| `net_paid_amount` | `DOUBLE` | Weekly shopper spend after coupon discounts |
| `total_retail_disc_abs` | `DOUBLE` | Weekly retail markdown total as a positive number |
| `total_coupon_disc_abs` | `DOUBLE` | Weekly shopper coupon discount total as a positive number |
| `total_coupon_match_disc_abs` | `DOUBLE` | Weekly manufacturer coupon match total as a positive number |
| `avg_basket_value` | `DOUBLE` | Average `sales_value` per distinct basket, rounded to 2 decimals |
| `avg_spend_per_household` | `DOUBLE` | Average `sales_value` per distinct household, rounded to 2 decimals |
| `return_or_void_lines` | `BIGINT` | Weekly count of return or void lines |
| `zero_value_lines` | `BIGINT` | Weekly count of zero value lines |
| `_gold_created_at` | `TIMESTAMP` | Build timestamp |

### 3. `gold.fact_product_promo_weekly`

* **Lineage:** Aggregates `silver.fact_transaction` (with `silver.dim_date` for `week_no`) to `(week_no, store_id, product_id)`, then left joins `silver.fact_store_promo_placement` and `silver.dim_product` (`sql/gold/02_fact_product_promo_weekly.sql`). Traces back to `bronze.raw_transaction_data`, `bronze.raw_store_promo_placement`, and `bronze.raw_product_inventory`.
* **Grain:** One row per `week_no`, `store_id`, and `product_id` (`2,370,784` rows).
* **Usage Notes:** Compare `promo_channel` states (`Display + Mailer`, `Display Only`, `Mailer Only`, and `No Promo`) to measure promotional lift. Unmatched store product weeks default to `No Promo`. Note that fuel products (`department = 'FUEL'`) record `quantity` in thousandths of a gallon, which inflates `No Promo` unit totals (`259,891,029` units across `1,887,464` rows, versus `412,148` in `Mailer Only`, `200,308` in `Display Only`, and `182,137` in `Display + Mailer`). Filter out `department = 'FUEL'` when comparing unit velocity for packaged goods.

| Column Name | Data Type | Description |
| :--- | :--- | :--- |
| `week_no` | `INTEGER` | Retail week number from 1 to 102 (primary key part 1) |
| `store_id` | `VARCHAR` | Store identifier (primary key part 2) |
| `product_id` | `VARCHAR` | Product identifier (primary key part 3) |
| `department` | `VARCHAR` | Product department from `silver.dim_product` |
| `commodity_desc` | `VARCHAR` | Product commodity group from `silver.dim_product` |
| `sub_commodity_desc` | `VARCHAR` | Product sub commodity group from `silver.dim_product` |
| `brand` | `VARCHAR` | Brand type such as National or Private from `silver.dim_product` |
| `manufacturer` | `VARCHAR` | Manufacturer code from `silver.dim_product` |
| `display_code` | `VARCHAR` | Store display placement code (`'0'` means no display) |
| `mailer_code` | `VARCHAR` | Circular mailer placement code (`'0'` means no mailer) |
| `is_on_display` | `BOOLEAN` | True when the product had an active display in that store and week |
| `is_in_mailer` | `BOOLEAN` | True when the product appeared in a weekly mailer for that store and week |
| `promo_channel` | `VARCHAR` | Combined promotion status: `Display + Mailer`, `Display Only`, `Mailer Only`, or `No Promo` |
| `total_line_items` | `BIGINT` | Weekly transaction lines for this product in this store |
| `distinct_baskets` | `BIGINT` | Unique baskets containing this product in this store and week |
| `distinct_households` | `BIGINT` | Unique households buying this product in this store and week |
| `total_units` | `DOUBLE` | Total units sold in that store and week |
| `gross_sales_value` | `DOUBLE` | Weekly shelf value before retail markdowns and coupon match discounts |
| `sales_value` | `DOUBLE` | Weekly net retailer sales revenue |
| `net_paid_amount` | `DOUBLE` | Weekly shopper spend after coupon discounts |
| `total_retail_disc_abs` | `DOUBLE` | Weekly retail markdown total as a positive number |
| `total_coupon_disc_abs` | `DOUBLE` | Weekly shopper coupon discount total as a positive number |
| `total_coupon_match_disc_abs` | `DOUBLE` | Weekly manufacturer coupon match total as a positive number |
| `_gold_created_at` | `TIMESTAMP` | Build timestamp |

### 4. `gold.fact_campaign_funnel`

* **Lineage:** Starts from `silver.dim_campaign` and joins pre aggregated metrics from `silver.bridge_campaign_audience` (with `silver.dim_household`), `silver.bridge_coupon_product`, `silver.fact_coupon_redemption`, and `silver.fact_transaction` filtered to each campaign's `start_day` through `end_day` window (`sql/gold/04_fact_campaign_funnel.sql`). Traces back to `bronze.raw_campaign_desc`, `bronze.raw_campaign_audience`, `bronze.raw_hh_demographic`, `bronze.raw_coupon_inventory`, `bronze.raw_coupon_redempt`, and `bronze.raw_transaction_data`.
* **Grain:** One row per `campaign_id` across all 30 campaigns (`5` `TypeA`, `19` `TypeB`, `6` `TypeC`).
* **Usage Notes:** Tracks progression from `targeted_households` to `active_shoppers_in_window`, `redeeming_households`, and `eligible_product_buyers`. Total targeted households from `silver.bridge_campaign_audience` serves as the funnel denominator so households without demographic records remain included. Both total redemptions and strict in window redemptions are provided because occasional coupon redemptions occur outside the listed campaign dates.

| Column Name | Data Type | Description |
| :--- | :--- | :--- |
| `campaign_id` | `VARCHAR` | Campaign identifier from 1 to 30 (primary key) |
| `campaign_type` | `VARCHAR` | Campaign group (`TypeA`, `TypeB`, or `TypeC`) |
| `start_day` | `INTEGER` | First day of the campaign window |
| `end_day` | `INTEGER` | Last day of the campaign window |
| `duration_days` | `INTEGER` | Total inclusive days in the campaign window |
| `eligible_coupons` | `BIGINT` | Count of distinct coupons linked to the campaign |
| `eligible_products` | `BIGINT` | Count of distinct products covered by campaign coupons |
| `targeted_households` | `BIGINT` | Unique households targeted in the campaign |
| `targeted_households_with_demo` | `BIGINT` | Targeted households with demographic profile details |
| `active_shoppers_in_window` | `BIGINT` | Targeted households making at least one purchase between `start_day` and `end_day` |
| `redeeming_households` | `BIGINT` | Unique households redeeming at least one campaign coupon |
| `redeeming_households_in_window` | `BIGINT` | Unique households redeeming a campaign coupon between `start_day` and `end_day` |
| `total_redemption_events` | `BIGINT` | Total coupon redemption records for the campaign |
| `in_window_redemption_events` | `BIGINT` | Coupon redemptions occurring between `start_day` and `end_day` |
| `redeemed_distinct_coupons` | `BIGINT` | Count of distinct coupons redeemed |
| `visit_rate_pct` | `DOUBLE` | Percentage of targeted households that shopped during the campaign window |
| `redemption_rate_pct` | `DOUBLE` | Percentage of targeted households that redeemed a campaign coupon |
| `active_shopper_redemption_rate_pct` | `DOUBLE` | Percentage of active window shoppers that redeemed a campaign coupon |
| `window_baskets` | `BIGINT` | Total baskets from targeted households during the campaign window |
| `window_units` | `DOUBLE` | Total units bought by targeted households during the campaign window |
| `window_gross_sales_value` | `DOUBLE` | Shelf value from targeted households during the campaign window |
| `window_sales_value` | `DOUBLE` | Net sales revenue from targeted households during the campaign window |
| `window_net_paid_amount` | `DOUBLE` | Shopper spend after coupon discounts during the campaign window |
| `window_coupon_disc_abs` | `DOUBLE` | Total shopper coupon discounts used during the campaign window |
| `window_coupon_match_disc_abs` | `DOUBLE` | Total manufacturer coupon match discounts during the campaign window |
| `eligible_product_buyers` | `BIGINT` | Targeted households purchasing at least one campaign eligible product in window |
| `eligible_product_units` | `DOUBLE` | Units of campaign eligible products bought by targeted households in window |
| `eligible_product_sales_value` | `DOUBLE` | Net sales on campaign eligible products bought by targeted households in window |
| `sales_per_targeted_household` | `DOUBLE` | Average `window_sales_value` per targeted household, rounded to 2 decimals |
| `_gold_created_at` | `TIMESTAMP` | Build timestamp |

## Reconciliation Summary

| Check | Silver Baseline | Gold Output | Status |
| :--- | :--- | :--- | :--- |
| Daily Store Sales Total | `$8,057,463.08` | `$8,057,463.08` in `gold.fact_sales_daily` | Matched |
| Weekly Store Sales Total | `$8,057,463.08` | `$8,057,463.08` in `gold.agg_sales_weekly` | Matched |
| Product Promo Sales Total | `$8,057,463.08` | `$8,057,463.08` in `gold.fact_product_promo_weekly` | Matched |
| Campaign Count | `30` campaigns | `30` campaigns in `gold.fact_campaign_funnel` | Matched |