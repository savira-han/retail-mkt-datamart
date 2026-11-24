# Retail Marketing Datamart

A retail marketing datamart project built using the **dunnhumby: The Complete Journey** dataset.

## Project Objectives

The datamart is designed to support three primary analytical areas:

**1. Sales Performance**
- Sales trends and transaction volume.
- Customer purchasing activity.
- Average basket value.
- Sales performance across stores and time periods.

**2. Product Performance**
- Product sales and purchase volume.
- Top-performing products.
- Product contribution to overall sales.
- Product purchasing patterns.

**3. Campaign Impact**
- Coupon distribution and redemption.
- Promotional performance.
- Customer response to promotions.
- Purchasing behavior during promotional periods.

## Data Source

**Source:** [dunnhumby The Complete Journey](https://www.dunnhumby.com/source-files/)

## Technology Stack

| Technology | Purpose |
|---|---|
| Python | Data ingestion and automation |
| SQL | Data transformation and modeling |
| DuckDB | Data storage and processing |
| GitHub | Version control and documentation |

## Data Architecture

The project follows a bronze, silver, and gold architecture.

| Layer | Description |
|---|---|
| Bronze | Ingested source data with schema enforcement |
| Silver | Structured analytical data, including fact and dimension tables |
| Gold | Business-ready datasets for sales, product, and campaign analysis |

### Development Workflow

1. Business understanding and analytical requirements.
2. Source data ingestion and schema enforcement.
3. Dimension modeling.
4. Fact table development.
5. Gold layer development.
6. Data quality checks and reconciliation.

Python is used primarily for ingestion and automation. SQL handles the subsequent transformations and data modeling within DuckDB.

## Repository Structure

```text
retail-marketing-datamart/
├── data/
│   ├── raw/
│   └── processed/
├── database/
├── src/
├── sql/
├── tests/
├── docs/
├── dashboard/
├── requirements.txt
└── README.md
```

The structure may change as the project develops.


*Note:*
*See [PROJECT_BRIEF.md](PROJECT_BRIEF.md) for the project objectives, business scope, architecture, development process, and design principles.*