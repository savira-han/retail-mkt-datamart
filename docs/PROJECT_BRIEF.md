# Retail Marketing Datamart

## 1. Project Overview

This project aims to build a retail marketing datamart using the **dunnhumby: The Complete Journey** dataset.

The datamart will transform the original source data into reliable and reusable analytical datasets that support three primary business purposes:

1. **Sales Performance**: Analyze overall sales performance, transaction trends, and business metrics.
2. **Product Performance**: Understand product sales, product contribution, and product details.
3. **Campaign Impact**: Evaluate campaign and promotional performance (coupon)

The project follows a Bronze,Silver, Gold architecture to separate source data, analytical models, and business-ready datasets.

## 2. Project Objectives

The main objective is to develop a reliable and reusable data foundation for retail marketing analysis.

With details aiming to:

- Consolidate the original datasets into a centralized analytical database.
- Establish consistent data structures, relationships, and business definitions.
- Develop reusable fact and dimension tables.
- Create business ready datasets for sales, product, and campaign analysis.
- Implement data quality checks processes.
- Establish a repeatable data ingestion and transformation workflow.

## 3. Business Scope

The datamart will focus on three analytical areas:

### 3.1 Sales Performance
Understand overall retail sales performance and purchasing activity.

### 3.2 Product Performance
Understand product level performance and purchasing behavior.

### 3.3 Campaign Impact
Understand the performance of marketing campaigns and promotional activities.

## 4. Data Source

The project uses the **dunnhumby: The Complete Journey** dataset.
The dataset contains retail transaction and marketing related information that can be used to explore purchasing behavior, product performance, store activity, and promotional engagement.

The original CSV files will be the Bronze layer. Findings and potential data quality issues are documented separately and will be considered during the modeling and transformation process.

## 5. Technology Stack

| Technology | Purpose |
|---|---|
| Python | Data ingestion and automation |
| SQL | Data transformation, modeling, and validation |
| DuckDB | Local analytical database and processing engine |
| GitHub | Version control and project documentation |

Python will primarily handle source data ingestion and automation. SQL will be used for the subsequent database transformations, analytical modeling, and data quality checks.

## 6. Data Architecture

The project follows a Bronze, Silver, Gold architecture.

### 6.1 Bronze Layer

The Bronze layer stores the ingested source data.

Include:

- Loading the original CSV datasets into DuckDB.
- Establishing consistent schemas and data types.
- Preserving the source information for downstream processing.
- Maintaining traceability between the original data and ingested records.

The Bronze layer should remain as close to the original source structure as reasonably possible.

### 6.2 Silver Layer

The Silver layer contains structured and standardized analytical data.

Include:

- Establishing shared date and time structures.
- Building dimension tables.
- Defining fact tables based on business events and their respective grains.
- Standardizing data types and business definitions.
- Addressing identified data quality issues through documented transformation rules.

The Silver layer will provide the reusable analytical foundation for the Gold layer.

### 6.3 Gold Layer

The Gold layer contains business-ready datasets designed around the analytical requirements.

It will support the three primary domains:

- Sales Performance
- Product Performance
- Campaign Impact

Gold datasets should provide the necessary metrics, dimensions, and business definitions for reporting and analysis without requiring users to repeatedly perform complex transformations.

## 7. Development Process

### Stage 1: Business Understanding

Define the analytical requirements and intended use cases.

- Identify the business questions.
- Understand the available source data.
- Identify relevant business entities and relationships.
- Establish the initial analytical requirements.

### Stage 2: Data Ingestion and Schema Enforcement

Load the source datasets into the Bronze layer.

- Implement Python based ingestion.
- Load source CSV files into DuckDB.
- Establish consistent schemas and data types.
- Validate ingestion results.
- Document source to Bronze reconciliation.

### Stage 3: Dimension Modeling

Develop the shared analytical dimensions in the Silver layer.

- Identify relevant dimensions.
- Design the date and time structure.
- Define dimension keys and relationships.
- Establish consistent attribute definitions.
- Validate dimension integrity.

### Stage 4: Fact Table Development

Develop fact tables based on the identified business events.

- Define the grain of each fact table.
- Identify relevant measures and foreign keys.
- Determine the appropriate relationships with dimensions.
- Implement transformations using SQL.
- Validate record counts, uniqueness, and referential integrity.

### Stage 5: Gold Layer Development

Build business-ready datasets for the three analytical domains.

- Develop sales performance datasets.
- Develop product performance datasets.
- Develop campaign impact datasets.
- Define and standardize analytical metrics.
- Validate business logic and aggregation results.

### Stage 6: Data Quality and Reconciliation

Establish automated quality checks across the data pipeline.

- Compare source and transformed record counts.
- Validate key relationships.
- Check for unexpected duplicates and missing values.
- Reconcile important business metrics across layers.
- Validate transformation outputs.
- Document known limitations and exceptions.

## 8. Principles

The project will follow these principles throughout development:

- **Business driven modeling:** Tables should be designed around analytical requirements rather than simply reproducing source tables.
- **Defined grain:** Every fact table must have a clearly documented grain.
- **Reliable relationships:** Table relationships and cardinality must be understood before performing joins.
- **Consistent definitions:** Business metrics should have standardized definitions across analytical domains.
- **Data traceability:** Transformations should be traceable to their original sources.
- **Reconciliation:** Important metrics and record counts should be validated between processing layers.
- **Documented assumptions:** Business rules and transformation decisions should be explicitly documented.
- **Reusable models:** Shared dimensions and business logic should be developed to avoid unnecessary duplication.

## 9. Expected Deliverables

1. A centralized DuckDB database containing the Bronze, Silver, and Gold layers.
2. A Python based source data ingestion workflow.
3. SQL based transformation and modeling scripts.
4. Reusable Silver fact and dimension tables.
5. Gold datasets supporting sales, product, and campaign analysis.
6. Data quality and reconciliation checks.
7. Technical documentation covering architecture, data models, and transformation logic.

The objective is not simply to load the source datasets into a database or convert every source table into a dimensional model. The datamart should provide a reliable analytical foundation that addresses actual business requirements.