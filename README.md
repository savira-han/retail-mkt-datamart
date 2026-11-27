# Retail Marketing Datamart

A retail marketing datamart project built using the **dunnhumby: The Complete Journey** dataset in a local DuckDB warehouse (`retailmkt.db`) across a three layer **Bronze -> Silver -> Gold** architecture.

## Project Objectives

The datamart supports three primary analytical areas:

**1. Sales Performance**
- Daily and weekly sales trends and transaction volume across stores.
- Customer purchasing activity, basket counts, and unique weekly shoppers.
- Average basket value and average spend per household.
- Sales performance across stores, days of the week, and time periods.

**2. Product Performance**
- Product sales and purchase volume across stores and retail weeks.
- Top performing products, departments, and commodities.
- Product contribution to overall sales (`$8,057,463.08` reconciled net sales).
- Promotional lift and purchasing patterns across store displays and weekly mailers.

**3. Campaign Impact**
- Coupon distribution, eligibility, and redemption tracking.
- End-to-end 4 stage campaign funnel conversion across all 30 campaigns (`TypeA`, `TypeB`, `TypeC`).
- Customer response to promotions and targeted outreach.
- Purchasing behavior and eligible product spend during active campaign windows.

## Data Source

**Source:** [dunnhumby The Complete Journey](https://www.dunnhumby.com/source-files/)

## Technology Stack

| Technology | Purpose |
|---|---|
| Python | Data ingestion, profiling, and SQL execution automation |
| SQL | Data transformation, dimensional modeling, and Gold mart queries |
| DuckDB | Local analytical database storage and query engine (`retailmkt.db`) |
| Git / GitHub | Version control and project documentation |

## Data Architecture & Current Status

The warehouse follows a **Bronze -> Silver -> Gold** architecture where each layer builds strictly on the layer below it:

| Layer | Schema | Description | Status |
|---|---|---|---|
| **Bronze** | `bronze` | Standardized source ingestion from raw CSVs with schema enforcement and audit metadata (`39,607,037` rows across 8 tables) | Complete |
| **Silver** | `silver` | Conformed dimensions (`dim_*`), many-to-many bridges (`bridge_*`), and explicit-grain fact tables (`fact_*`) | Complete |
| **Gold** | `gold` | Analytical marts for Sales, Product/Promo, and Campaign Funnel domains (`fact_sales_daily`, `fact_product_promo_weekly`, `agg_sales_weekly`, `fact_campaign_funnel`) | Complete & Reconciled |

### Development Workflow

1. Business understanding and analytical requirements.
2. Source data ingestion and schema enforcement (`bronze`).
3. Dimension, bridge, and fact modeling (`silver`).
4. Analytical mart development (`gold`).
5. Data quality checks, grain verification, and financial reconciliation (`$8,057,463.08` net sales across sales and product-promo tables; all 30 campaigns verified).
6. Documentation and downstream reporting/dashboards.

Python handles ingestion, profiling, and SQL runner automation, while SQL defines the Silver and Gold transformations inside DuckDB.

## Processed Data Samples

The `data/processed/` directory contains sample CSV exports of selected tables from the Gold layer.

These files provide a lightweight preview of the final analytical tables without requiring access to the full DuckDB database.

| File | Source Gold Table | Description |
|---|---|---|
| `agg_sales_weekly.csv` | `gold.agg_sales_weekly` | Weekly sales aggregation |
| `fact_campaign_funnel.csv` | `gold.fact_campaign_funnel` | Campaign funnel performance |
| `fact_product_promo_weekly.csv` | `gold.fact_product_promo_weekly` | Weekly product sales and promotional performance |
| `fact_sales_daily.csv` | `gold.fact_sales_daily` | Daily sales performance |

**Sample export details:**
- Each CSV contains a random sample of up to 1,000 rows from its corresponding Gold table.
- All columns are retained in the exported files.
- Samples are intended for preview, inspection, and demonstration purposes.
- The samples may differ between export runs because row selection is random.
- These CSV files do not represent the complete Gold tables and should not be used as substitutes for the full analytical datasets.

The complete Gold tables are available in the DuckDB database (`retailmkt.db`).

## Repository Structure

```text
retail-marketing-datamart/
├── data
│   ├── processed_sample
│   │   ├── README.md
│   │   ├── sample_agg_sales_weekly.csv
│   │   ├── sample_fact_campaign_funnel.csv
│   │   ├── sample_fact_product_promo_weekly.csv
│   │   └── sample_fact_sales_daily.csv
│   ├── raw
│   │   ├── campaign_desc.csv
│   │   ├── campaign_table.csv
│   │   ├── causal_data.csv
│   │   ├── coupon_redempt.csv
│   │   ├── coupon.csv
│   │   ├── hh_demographic.csv
│   │   ├── product.csv
│   │   ├── README.md
│   │   └── transaction_data.csv
│   └── warehouse
│       ├── README.md
│       └── retailmkt.db
├── docs
│   ├── DATA_DESIGN.md
│   ├── DATA_INFORMATION.md
│   ├── DATAMART_DETAILS.md
│   └── PROJECT_BRIEF.md
├── README.md
├── requirements.txt
├── sql
│   ├── analytics
│   ├── gold
│   │   ├── 00_check_tally.sql
│   │   ├── 01_fact_sales_daily.sql
│   │   ├── 02_fact_product_promo_weekly.sql
│   │   ├── 03_agg_sales_weekly.sql
│   │   └── 04_fact_campaign_funnel.sql
│   └── silver
│       ├── 00_build_all_silver.sql
│       ├── 01_dim_date.sql
│       ├── 02_dim_product.sql
│       ├── 03_dim_household.sql
│       ├── 04_dim_campaign.sql
│       ├── 05_dim_store.sql
│       ├── 06_bridge_campaign_audience.sql
│       ├── 07_bridge_coupon_product.sql
│       ├── 08_fact_transaction.sql
│       ├── 09_fact_coupon_redemption.sql
│       └── 10_fact_store_promo_placement.sql
└── src
    ├── ingestion
    │   ├── 01_check_bronze.py
    │   ├── 01_ingest_bronze.py
    │   ├── 02_check_silver.py
    │   ├── 02_ingest_silver.py
    │   ├── 03_check_gold.py
    │   └── 03_gold_csv_sample.py
    ├── profiling
    │   ├── 00_list_source_tables.py
    │   ├── 01_table_profile.py
    │   ├── 02_unique_profile.py
    │   └── README.md
    └── utils
        ├── check_size.py
        └── run_sql.py
```