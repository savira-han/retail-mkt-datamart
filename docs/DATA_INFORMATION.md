# DATA INFORMATION

### 1. Overview

This document is a compilation of information gathered from internet, regarding the data used (The Complete Journey). The Complete Journey is a grocery retail dataset provided by dunnhumby. It contains approximately 2 years of shopping and marketing activity from 2,500 households participating in a retailer's loyalty program.

The dataset combines household purchase history, product information, household demographics, marketing campaigns, coupon activity, and promotional placement information.

It can support analysis of:

1. Sales performance and purchasing patterns
2. Product and category performance
3. Customer purchasing behavior
4. Campaign and coupon performance
5. Promotional effectiveness
6. Household segmentation and customer value analysis

The dataset consists of eight CSV files.

**Reference:** [The Complete Journey User Guide](https://raw.githubusercontent.com/Lanbig/CSC465-visualization-project/master/Dataset/dunnhumby%20-%20The%20Complete%20Journey%20User%20Guide.pdf)

### 2. Source Tables

#### 2.1 transaction_data

**Purpose:** Records household purchases at product level.

**Grain:** One product line within a shopping basket.

**Approximate rows:** 2,595,732

**Columns:**
- `household_key`: Household identifier
- `BASKET_ID`: Shopping basket identifier
- `DAY`: Relative day of the transaction
- `PRODUCT_ID`: Product identifier
- `QUANTITY`: Quantity purchased
- `SALES_VALUE`: Recorded sales value
- `STORE_ID`: Store identifier
- `RETAIL_DISC`: Retail discount
- `TRANS_TIME`: Transaction time
- `WEEK_NO`: Relative week number
- `COUPON_DISC`: Coupon discount
- `COUPON_MATCH_DISC`: Manufacturer coupon discount contribution

**Candidate key:** `BASKET_ID` and `PRODUCT_ID`. Validate uniqueness against the actual data before treating this as the primary key.

**Important notes:**
- This is the main purchase table.
- A basket can contain multiple products.
- `BASKET_ID` identifies a shopping occasion, not an individual product line.
- Discount values may be negative.
- `SALES_VALUE` and discount fields must be understood before defining revenue or gross sales metrics.

#### 2.2 product

**Purpose:** Provides product attributes and classification.

**Grain:** One row per product.

**Approximate rows:** 92,353

**Columns:**
- `PRODUCT_ID`: Product identifier
- `MANUFACTURER`: Manufacturer identifier
- `DEPARTMENT`: Product department
- `BRAND`: Brand classification
- `COMMODITY_DESC`: Product category
- `SUB_COMMODITY_DESC`: Product subcategory
- `CURR_SIZE_OF_PRODUCT`: Product size description

**Candidate primary key:** `PRODUCT_ID`.

**Important notes:**
- Can be joined to purchase records using `PRODUCT_ID`.
- Supports product, brand, department, and category analysis.
- Some product descriptions may be missing or contain placeholder values.

#### 2.3 hh_demographic

**Purpose:** Contains demographic information about participating households.

**Grain:** One row per household with available demographic information.

**Approximate rows:** 801

**Columns:**
- `household_key`: Household identifier
- `AGE_DESC`: Estimated age range
- `MARITAL_STATUS_CODE`: Marital status
- `INCOME_DESC`: Household income range
- `HOMEOWNER_DESC`: Home ownership status
- `HH_COMP_DESC`: Household composition
- `HOUSEHOLD_SIZE_DESC`: Household size
- `KID_CATEGORY_DESC`: Number of children category

**Candidate primary key:** `household_key`.

**Important notes:**
- Demographic information is not available for every household.
- The dataset contains 2,500 households, but this table covers only a subset.
- Missing demographic records should not automatically be treated as invalid households.
- Useful for household segmentation and demographic analysis.

#### 2.4 campaign_desc

**Purpose:** Provides campaign information and campaign schedules.

**Grain:** One row per campaign.

**Approximate rows:** 30

**Columns:**
- `CAMPAIGN`: Campaign identifier
- `DESCRIPTION`: Campaign type
- `START_DAY`: Campaign start day
- `END_DAY`: Campaign end day

**Candidate primary key:** `CAMPAIGN`.

**Important notes:**
- Contains campaign types such as TypeA, TypeB, and TypeC.
- Defines the period during which a campaign runs.
- Campaign dates use relative day values rather than calendar dates.

#### 2.5 campaign_table

**Purpose:** Records which campaigns were sent to each household.

**Grain:** One household and campaign combination.

**Approximate rows:** 7,208

**Columns:**
- `DESCRIPTION`: Campaign type
- `household_key`: Household identifier
- `CAMPAIGN`: Campaign identifier

**Candidate composite key:** `household_key` and `CAMPAIGN`.

**Important notes:**
- A household can receive multiple campaigns.
- A campaign can be sent to multiple households.
- This table represents campaign participation or targeting, not actual coupon redemption.
- `DESCRIPTION` repeats campaign information available in `campaign_desc`.

#### 2.6 coupon

**Purpose:** Maps coupons to the products for which they can be redeemed within a campaign.

**Grain:** One coupon, product, and campaign combination.

**Approximate rows:** 124,548

**Columns:**
- `COUPON_UPC`: Coupon identifier
- `PRODUCT_ID`: Eligible product identifier
- `CAMPAIGN`: Campaign identifier

**Candidate composite key:** `COUPON_UPC`, `PRODUCT_ID`, and `CAMPAIGN`.

**Important notes:**
- A coupon can be valid for multiple products.
- This creates a many to many relationship between coupons and products.
- The table describes coupon eligibility, not actual redemption.
- Campaign TypeA has an additional consideration: the table represents the pool of possible coupons, not necessarily the exact coupons received by each household.

#### 2.7 coupon_redempt

**Purpose:** Records coupons actually redeemed by households.

**Grain:** One coupon redemption record.

**Approximate rows:** 2,318

**Columns:**
- `household_key`: Household identifier
- `DAY`: Redemption day
- `COUPON_UPC`: Coupon identifier
- `CAMPAIGN`: Campaign identifier

**Candidate composite key:** `household_key`, `DAY`, `COUPON_UPC`, and `CAMPAIGN`.

**Important notes:**
- Represents actual coupon redemption activity.
- Can be used to study coupon usage and campaign response.
- Redemption is different from campaign participation or coupon eligibility.
- Validate the proposed key against the source data.

#### 2.8 causal_data

**Purpose:** Records promotional placement information for products across stores and weeks.

**Grain:** One product, store, and week combination.

**Approximate rows:** 36,786,524

**Columns:**
- `PRODUCT_ID`: Product identifier
- `STORE_ID`: Store identifier
- `WEEK_NO`: Relative week number
- `display`: In store display placement code
- `mailer`: Mailer or advertising placement code

**Candidate composite key:** `PRODUCT_ID`, `STORE_ID`, and `WEEK_NO`.

**Important notes:**
- `display` describes in store promotional placement.
- `mailer` describes promotional placement in advertising mailers.
- Both fields contain categorical codes, not numerical measurements.
- This table has a different level of detail from transaction records.
- Aggregate or match the data carefully before joining it to transaction records.

**Table structure reference:** [Community Dataset Schema Documentation](https://github.com/bltap-plmarket/dunnhumby-complete-journey/blob/main/docs/SCHEMA.md)

### 3. Key Relationships

The main identifiers connecting the source tables are:

| Key | Connected tables |
|---|---|
| `household_key` | transaction_data, hh_demographic, campaign_table, coupon_redempt |
| `PRODUCT_ID` | transaction_data, product, coupon, causal_data |
| `STORE_ID` | transaction_data, causal_data |
| `CAMPAIGN` | campaign_desc, campaign_table, coupon, coupon_redempt |
| `COUPON_UPC` | coupon, coupon_redempt |
| `WEEK_NO` | transaction_data, causal_data |
| `DAY` | transaction_data, coupon_redempt, campaign_desc through campaign period |

These relationships describe possible joins. They do not guarantee that every join is one to one.

### 4. Important Dataset Characteristics

**Household coverage**

The study includes 2,500 households. However, demographic information is available for only a subset of them. Campaign participation and coupon redemption also cover different subsets of households.

**Relative time values**

`DAY` and `WEEK_NO` are relative time identifiers. They should not be interpreted as calendar dates without an established reference date.

**No store master table**

The dataset contains `STORE_ID`, but does not provide a dedicated store table with store names, locations, or other store attributes.

**Different data grains**

The tables describe different levels of detail. For example, transaction records are at product line level, while promotional records are at product, store, and week level.

**Coupon relationships**

Coupon eligibility, campaign participation, and coupon redemption are separate business events. They should not be treated as interchangeable.

**Discount values**

Discount fields may use negative values. Their signs and business meanings should be investigated before creating financial metrics.

**Potential duplicates**

Repeated records do not automatically indicate errors. Their meaning depends on the intended grain of each table. This is particularly important when examining the coupon table.

### 5. Potential Analytical Use Cases

| Analytical area | Possible questions |
|---|---|
| Sales performance | How do sales change over time? Which stores and households contribute most to sales? |
| Product performance | Which products, brands, and categories generate the most sales? |
| Customer behavior | How frequently do households shop? What products do they purchase? |
| Campaign performance | How do purchasing patterns differ between households that received campaigns and those that did not? |
| Coupon performance | Which coupons are redeemed most frequently? Which eligible products are purchased? |
| Promotional effectiveness | How do product sales relate to in store displays and mailer placements? |
| Household segmentation | How do purchasing patterns differ across household demographic groups? |

These are possible analytical directions, not conclusions that can be established from the source tables alone.

### 6. Data Preparation Considerations

1. **Grain and uniqueness:** Confirm the intended grain and candidate key of every source table.
2. **Data types:** Check whether identifiers, dates, quantities, and financial values have appropriate data types.
3. **Missing values:** Identify missing or incomplete information and determine how it should be handled.
4. **Duplicate records:** Investigate duplicates in the context of each table's intended grain.
5. **Relationships:** Validate foreign key relationships and identify unmatched records.
6. **Join cardinality:** Check whether joins create unexpected row multiplication.
7. **Business definitions:** Establish consistent definitions for sales, discounts, campaign participation, and coupon redemption.
8. **Time consistency:** Understand the relationship between `DAY`, `WEEK_NO`, and campaign periods.
9. **Categorical values:** Review the distinct values and meanings of fields such as `display`, `mailer`, and `DESCRIPTION`.

Do not assume that a candidate key, relationship, or business rule is valid until it has been checked against the actual source data.

### 7. Reference Sources

The following sources provide supporting information about the dataset:

1. **The Complete Journey User Guide:** [Open User Guide](https://raw.githubusercontent.com/Lanbig/CSC465-visualization-project/master/Dataset/dunnhumby%20-%20The%20Complete%20Journey%20User%20Guide.pdf)  
   Explains the business meaning of campaigns, coupons, transactions, products, and promotional placement.

2. **Community Dataset Schema Documentation:** [Open Schema Documentation](https://github.com/bltap-plmarket/dunnhumby-complete-journey/blob/main/docs/SCHEMA.md)  
   Provides a reference for table structures, documented grains, row counts, and suggested relationships.

3. **Data Lake Dataset README:** [Open Dataset README](https://github.com/dataseer-carl/data-lake/blob/master/dunnhumby_The-Complete-Journey/readme.md)  
   Provides additional table descriptions, schemas, and sample records.

4. **CompleteJourney R Package Documentation:** [Open Package Guide](https://bradleyboehmke.github.io/completejourney/)  
   Provides an additional reference for the dataset and its analytical context.

The user guide is the primary reference for understanding business meaning. Community documentation is useful for comparison, but should not be treated as the definitive authority.

### 8. Final Note

The Complete Journey dataset brings together purchase history, household information, product attributes, campaign targeting, coupon activity, and promotional placement.

Its main analytical value comes from connecting these different sources while respecting their individual levels of detail.

The source documentation provides a starting point. The actual data profiling, validation, and business interpretation should determine the final data definitions and relationships used in the project.