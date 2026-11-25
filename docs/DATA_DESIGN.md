# DATA DESIGN

## 1. Architecture Overview

This project follows a **Bronze → Silver → Gold** layered architecture backed by a local DuckDB database (`data/warehouse/retailmkt.db`), Python ingestion scripts (`src/ingestion/`), and SQL modeling/validation scripts (`sql/`, `tests/`).

| Layer | Schema | Purpose | Status |
|---|---|---|---|
| **Bronze** | `bronze` | Standardized source ingestion from raw CSVs with traceability metadata | Active |
| **Silver** | `silver` | Conformed dimensions and explicit-grain fact tables | - |
| **Gold** | `gold` | Analytical datasets for Sales, Product, and Campaign domains | - |

---

## 2. Bronze Data

### 2.1 Bronze Ingestion Process

Raw CSV files in `data/raw/` are loaded into `retailmkt.db` under the `bronze` schema by the Python ingestion pipeline (`src/ingestion/`):

1. **File Discovery & Table Naming:**
   - Scans non-hidden `.csv` files in `data/raw/` sorted by filename.
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

### 2.2 Post-Ingestion Bronze Inventory

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
*Incoming*

---

## 4. Gold Data
*Incoming*