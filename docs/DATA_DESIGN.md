# DATA DESIGN

## 1. Architecture Overview

This project follows a **Bronze → Silver → Gold** layered architecture backed by a local DuckDB database (`data/warehouse/retailmkt.db`), Python ingestion scripts (`src/ingestion/`), and SQL modeling/validation scripts (`sql/`, `tests/`).

| Layer | Schema | Purpose | Status |
|---|---|---|---|
| **Bronze** | `bronze` | Standardized source ingestion from raw CSVs with traceability metadata | Active |
| **Silver** | `silver` | Conformed dimensions and explicit grain fact tables | Active |
| **Gold** | `gold` | Analytical datasets for Sales, Product, and Campaign domains | - |

---

## 2. Bronze Data

### 2.1 Bronze Ingestion Process

Raw CSV files in `data/raw/` are loaded into `retailmkt.db` under the `bronze` schema by the Python ingestion pipeline (`src/ingestion/`):

1. **File Discovery & Table Naming:**
  - Scans non hidden `.csv` files in `data/raw/` sorted by filename.
  - Normalizes source stems to lowercase and applies explicit table renames:
    - `campaign_table.csv` → `campaign_audience`
    - `coupon.csv` → `coupon_inventory`
    - `product.csv` → `product_inventory`
    - `causal_data.csv` → `store_promo_placement`
    - Remaining CSVs retain their source stem name (`campaign_desc`, `coupon_redempt`, `hh_demographic`, `transaction_data`).
  - Prefixes every target table name with `raw_` (for example, `raw_product_inventory`).

2. **String-First Reading & Column Normalization:**
- Reads raw CSVs as strings (`dtype=str`) first so identifier/code columns preserve leading zeros and do not gain trailing `.0` artifacts from float parsing.
  - Standardizes all column names to lowercase (`str.strip().lower()`).

3. **Schema Type Enforcement:**
- Casts columns per table to standardized types:
  - **Identifiers, codes, and categorical/descriptive attributes** (such as `household_key`, `basket_id`, `product_id`, `store_id`, `coupon_upc`, `campaign`, `day`, `display`, `mailer`, `brand`, `department`, `commodity_desc`, `sub_commodity_desc`, `curr_size_of_product`, `description`, demographic classifications): `string` (with whitespace trimmed and trailing `.0` removed).
    - **Integer measures/periods** (such as `start_day`, `end_day`, `week_no`, `quantity`, `trans_time`, and `day` in `coupon_redempt`): nullable integer (`Int64`).
    - **Decimal financial/discount measures** (such as `sales_value`, `retail_disc`, `coupon_disc`, `coupon_match_disc`): `float64`.

---

### 2.2 Post Ingestion Bronze Inventory

Total rows ingested across all 8 Bronze tables: **39,607,037** rows.

| Source File | DuckDB Table | Rows Ingested | Bronze Columns (incl. 2 Audit Cols) | Source Columns | Primary Role / Notes |
|---|---|---|---|---|---|
| `campaign_desc.csv` | `bronze.raw_campaign_desc` | 30 | 6 | 4 | Campaign type (`description`) and active day window (`start_day`, `end_day`) |
| `campaign_table.csv` | `bronze.raw_campaign_audience` | 7,208 | 5 | 3 | Household to campaign mapping (`household_key`, `campaign`) |
| `causal_data.csv` | `bronze.raw_store_promo_placement` | 36,786,524 | 7 | 5 | Store week promotional placement (`display`, `mailer`) by product and store |
| `coupon.csv` | `bronze.raw_coupon_inventory` | 124,548 | 5 | 3 | Coupon offer mapping (`coupon_upc`, `product_id`, `campaign`) |
| `coupon_redempt.csv` | `bronze.raw_coupon_redempt` | 2,318 | 6 | 4 | Coupon redemption events (`household_key`, `coupon_upc`, `campaign`, `day`) |
| `hh_demographic.csv` | `bronze.raw_hh_demographic` | 801 | 10 | 8 | Household demographic attributes (`household_key` subset) |
| `product.csv` | `bronze.raw_product_inventory` | 92,353 | 9 | 7 | Product catalog attributes (department, commodity, brand, size) |
| `transaction_data.csv` | `bronze.raw_transaction_data` | 2,595,732 | 14 | 12 | Basket line item transactions, quantities, sales, and discounts |

---

## 3. Silver Data

### 3.1 Silver Transformation Process

The `silver` schema is built in dependency order by `src/ingestion/ingest_silver.py`, which executes `sql/silver/00_build_all_silver.sql` against `retailmkt.db`:

1. **Conformed Dimensions (`silver.dim_*`):**
   - **Time Spine (`dim_date`):** Generates a continuous integer `day_num` spine from `MIN(day)` to `MAX(day)` across transactions, redemptions, and campaign windows, mapping each `day_num` to `week_no` (preferring transaction `week_no`, falling back to `((day_num - 1) // 7) + 1`) and deriving `day_of_week_num` and `is_weekend_slot`.
   - **Full Household Spine (`dim_household`):** Combines all distinct `household_key`s from transactions, campaign audiences, coupon redemptions, and demographics before `LEFT JOIN`ing `bronze.raw_hh_demographic`. Prevents dropping active shoppers lacking demographic profiles, flags `has_demographic_profile`, and defaults missing `classification_1`–`classification_5`, `homeowner_desc`, and `kid_category_desc` to `'Unknown'`.
   - **Catalog & Entities (`dim_product`, `dim_campaign`, `dim_store`):** Trims identifiers, normalizes empty categorical values to `'Unknown'`, calculates `duration_days` for campaigns, and unions distinct `store_id`s across transactions and store promotional placements.

2. **Many to Many Bridges (`silver.bridge_*`):**
   - Isolates `bridge_campaign_audience` and `bridge_coupon_product` at their natural composite keys so downstream fact tables (`fact_coupon_redemption` and `fact_transaction`) do not suffer row fan-out during joins.

3. **Explicit Grain Facts (`silver.fact_*`):**
   - **Deterministic Surrogate Keys:** Generates `order_detail_id` (`basket_id`, `product_id`, `trans_time`, `line_seq`) and `coupon_redemption_id` (`household_key`, `coupon_upc`, `campaign_id`, `day_num`, `redemption_seq`) using `ROW_NUMBER()` tie breakers to prevent collisions on same minute rescans or same day redemptions.
   - **Standardized Transaction Math & Flags (`fact_transaction`):** Parses `trans_hour` and `time_of_day_bucket` (`Morning`, `Afternoon`, `Evening`, `Night`), computes standardized `gross_sales_value` and `net_paid_amount`, and preserves negative/zero return or void rows with `is_return_or_void` and `is_zero_value` flags rather than filtering them out.
   - **Weekly Promo Status (`fact_store_promo_placement`):** Maintains `causal_data` at its native `(store_id, product_id, week_no)` grain rather than flattening into transactions or product dimensions, deduplicating keys and deriving boolean `is_on_display` and `is_in_mailer` flags from `display_code` and `mailer_code`.

4. **Audit Metadata:**
   - Every Silver table includes `_silver_created_at` (`TIMESTAMP`) recording when the table was materialized.

---

### 3.2 Silver Design Rationale & Key Decisions

- **Why keep `fact_store_promo_placement` as a fact table instead of a dimension?**
  In dimensional modeling, dimensions describe entities or attributes, whereas facts record observations or events at a specific grain. Promotional placement (`display` and `mailer`) varies by `store_id`, `product_id`, and `week_no` across ~36.8M observations. Keeping it as a separate fact table at `(store_id, product_id, week_no)` avoids bloating product attributes with time-varying store observations and prevents row multiplication when joining to basket line items. In Gold, it can be joined to weekly store-product sales rollups to measure promotional lift.
- **Why split bridges (`bridge_campaign_audience`, `bridge_coupon_product`) instead of pre-joining into dimensions or facts?**
  A single campaign targets many households, a single household can receive multiple campaigns, and a single `coupon_upc` can cover multiple eligible `product_id`s. Merging those relationships directly into `dim_campaign` or `fact_coupon_redemption` changes the table grain and causes row fan-out when querying totals. Keeping bridges separate makes fan-out explicit and controlled only when needed.
- **Why build a full `household_key` spine in `dim_household`?**
  `bronze.raw_hh_demographic` only contains demographic rows for a subset of households (801 rows) compared to all active households appearing in transactions, campaigns, and redemptions. Joining directly to `raw_hh_demographic` or using an inner join would silently exclude non-demographic shoppers from household and revenue analysis. Building the full spine first and using a `LEFT JOIN` with `has_demographic_profile` and `'Unknown'` defaults preserves complete shopper coverage.
- **Why keep returns and zero-value rows in `fact_transaction` with flags instead of deleting them?**
  Negative or zero `quantity` and `sales_value` rows represent returns, voids, or coupon adjustments. Deleting them in Silver erases auditability and distorts net vs. gross revenue reconciliation. Flagging them (`is_return_or_void`, `is_zero_value`) lets Gold models choose whether to include or filter them while keeping Silver faithful to source accounting.
- **Why compute `gross_sales_value` and `net_paid_amount` in Silver?**
  In dunnhumby, discount columns (`retail_disc`, `coupon_disc`, `coupon_match_disc`) carry negative or zero signs, and `sales_value` already reflects `retail_disc` and `coupon_match_disc` deductions while excluding `coupon_disc` from out-of-pocket spend. Centralizing these formulas in `silver.fact_transaction` ensures consistent revenue math across all Gold models and reports.
- **Why add `ROW_NUMBER()` tie breakers to `order_detail_id` and `coupon_redemption_id`?**
  Concatenating natural attributes alone (`basket_id`, `product_id`, `trans_time` or `household_key`, `coupon_upc`, `campaign`, `day`) can collide if the same SKU is scanned multiple times within the same minute or if the same coupon is redeemed more than once on the same day. Adding a deterministic sequence suffix guarantees unique primary keys without dropping valid rows.
- **Why defer aggregations and cross-grain lift joins to Gold?**
  Silver establishes clean, conformed, atomic-grain building blocks so Gold can compute CLV, basket summaries, funnel conversion, and campaign/promo lift without repeating low-level type casting, null handling, or deduplication logic.

---

### 3.3 Silver Inventory & Grains

| Silver Table | Source Bronze Table(s) | Grain / Primary Key | Key Columns Added / Standardized |
|---|---|---|---|
| `silver.dim_date` | `raw_transaction_data`, `raw_coupon_redempt`, `raw_campaign_desc` | `day_num` | `day_num`, `week_no`, `day_of_week_num`, `is_weekend_slot`, `_silver_created_at` |
| `silver.dim_product` | `raw_product_inventory` | `product_id` | `product_id`, `manufacturer`, `department`, `brand`, `commodity_desc`, `sub_commodity_desc`, `curr_size_of_product`, `_silver_created_at` |
| `silver.dim_household` | `raw_transaction_data`, `raw_campaign_audience`, `raw_coupon_redempt`, `raw_hh_demographic` | `household_key` | `household_key`, `has_demographic_profile`, `classification_1`–`classification_5`, `homeowner_desc`, `kid_category_desc`, `_silver_created_at` |
| `silver.dim_campaign` | `raw_campaign_desc` | `campaign_id` | `campaign_id`, `campaign_type`, `start_day`, `end_day`, `duration_days`, `_silver_created_at` |
| `silver.dim_store` | `raw_transaction_data`, `raw_store_promo_placement` | `store_id` | `store_id`, `_silver_created_at` |
| `silver.bridge_campaign_audience` | `raw_campaign_audience` | `(household_key, campaign_id)` | `household_key`, `campaign_id`, `campaign_type`, `_silver_created_at` |
| `silver.bridge_coupon_product` | `raw_coupon_inventory` | `(coupon_upc, product_id, campaign_id)` | `coupon_upc`, `product_id`, `campaign_id`, `_silver_created_at` |
| `silver.fact_transaction` | `raw_transaction_data` | `order_detail_id` | `order_detail_id`, `trans_hour`, `time_of_day_bucket`, `gross_sales_value`, `net_paid_amount`, `is_return_or_void`, `is_zero_value`, `_silver_created_at` |
| `silver.fact_coupon_redemption` | `raw_coupon_redempt` | `coupon_redemption_id` | `coupon_redemption_id`, `household_key`, `coupon_upc`, `campaign_id`, `day_num`, `_silver_created_at` |
| `silver.fact_store_promo_placement` | `raw_store_promo_placement` | `(store_id, product_id, week_no)` | `store_id`, `product_id`, `week_no`, `display_code`, `mailer_code`, `is_on_display`, `is_in_mailer`, `_silver_created_at` |

---

## 4. Gold Data
*Incoming*