# Processed Data Sample

This directory contains sample CSV exports of selected tables from the Gold layer.

Each CSV file contains a random sample of up to 1,000 rows from its corresponding Gold table. The samples are provided for data preview, inspection, and documentation purposes.

## Available Files

| File | Description |
|---|---|
| `agg_sales_weekly.csv` | Sample of the weekly sales aggregation table |
| `fact_campaign_funnel.csv` | Sample of the campaign funnel fact table |
| `fact_product_promo_weekly.csv` | Sample of the weekly product promotion fact table |
| `fact_sales_daily.csv` | Sample of the daily sales fact table |

## Important Notes

- All files are exported from the Gold layer of the DuckDB database.
- Each file contains up to 1,000 randomly selected rows.
- Column names and data types reflect the corresponding Gold tables, although CSV itself does not preserve database data types.
- The samples may differ between export runs because row selection is random.
- These files are intended for preview and inspection, not as complete datasets for analysis.

For complete data, refer to the original Gold tables in the DuckDB database.