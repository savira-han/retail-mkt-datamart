from datetime import datetime, timezone
from pathlib import Path
import duckdb
import pandas as pd

PROJECT_ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = PROJECT_ROOT / "data" / "raw"
DB_PATH = PROJECT_ROOT / "data" / "warehouse" / "retailmkt.db"

TABLE_RENAMES: dict[str, str] = {
    "campaign_table": "campaign_audience",
    "coupon": "coupon_inventory",
    "product": "product_inventory",
    "causal_data": "store_promo_placement",
}

COLUMN_DTYPES: dict[str, dict[str, str]] = {
    "raw_campaign_desc": {
        "description": "string",
        "campaign": "string",
        "start_day": "Int64",
        "end_day": "Int64",
    },
    "raw_campaign_audience": {
        "description": "string",
        "household_key": "string",
        "campaign": "string",
    },
    "raw_store_promo_placement": {
        "product_id": "string",
        "store_id": "string",
        "week_no": "Int64",
        "display": "string",
        "mailer": "string",
    },
    "raw_coupon_inventory": {
        "coupon_upc": "string",
        "product_id": "string",
        "campaign": "string",
    },
    "raw_coupon_redempt": {
        "household_key": "string",
        "day": "Int64",
        "coupon_upc": "string",
        "campaign": "string",
    },
    "raw_hh_demographic": {
        "classification_1": "string",
        "classification_2": "string",
        "classification_3": "string",
        "homeowner_desc": "string",
        "classification_5": "string",
        "classification_4": "string",
        "kid_category_desc": "string",
        "household_key": "string",
    },
    "raw_product_inventory": {
        "product_id": "string",
        "manufacturer": "string",
        "department": "string",
        "brand": "string",
        "commodity_desc": "string",
        "sub_commodity_desc": "string",
        "curr_size_of_product": "string",
    },
    "raw_transaction_data": {
        "household_key": "string",
        "basket_id": "string",
        "day": "string",
        "product_id": "string",
        "quantity": "Int64",
        "sales_value": "float64",
        "store_id": "string",
        "retail_disc": "float64",
        "trans_time": "Int64",
        "week_no": "Int64",
        "coupon_disc": "float64",
        "coupon_match_disc": "float64",
    },
}


def resolve_table_name(source_stem: str) -> str:
    normalized = source_stem.strip().lower()
    base_name = TABLE_RENAMES.get(normalized, normalized)
    return base_name if base_name.startswith("raw_") else f"raw_{base_name}"


def clean_string_id_series(s: pd.Series) -> pd.Series:
    # Strip trailing ".0" if an integer-like ID was parsed as float by pandas
    as_str = s.astype("string").str.strip()
    return as_str.str.replace(r"\.0$", "", regex=True)


def cast_columns(df: pd.DataFrame, table_name: str) -> pd.DataFrame:
    df = df.copy()
    df.columns = [str(col).strip().lower() for col in df.columns]

    dtype_map = COLUMN_DTYPES.get(table_name, {})
    for col, target_dtype in dtype_map.items():
        if col not in df.columns:
            continue
        if target_dtype == "string":
            df[col] = clean_string_id_series(df[col])
        elif target_dtype == "Int64":
            numeric = pd.to_numeric(df[col], errors="coerce")
            df[col] = numeric.round().astype("Int64")
        elif target_dtype == "float64":
            df[col] = pd.to_numeric(df[col], errors="coerce").astype("float64")
        else:
            df[col] = df[col].astype(target_dtype)

    return df


def ingest_csvs_to_duckdb(
    raw_dir: Path = RAW_DIR,
    db_path: Path = DB_PATH,
    schema: str = "bronze",
) -> pd.DataFrame:
    if not raw_dir.is_dir():
        raise FileNotFoundError(f"Raw directory not found: {raw_dir}")

    db_path.parent.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(str(db_path))
    ingested_at = datetime.now(timezone.utc)
    summary: list[dict[str, object]] = []

    try:
        con.execute(f"CREATE SCHEMA IF NOT EXISTS {schema};")

        csv_files = sorted(
            p
            for p in raw_dir.iterdir()
            if p.is_file() and not p.name.startswith(".") and p.suffix.lower() == ".csv"
        )

        for csv_path in csv_files:
            target_table = resolve_table_name(csv_path.stem)

            # Read raw strings first so leading zeros in IDs/codes are preserved
            raw_df = pd.read_csv(csv_path, dtype=str, keep_default_na=True)
            typed_df = cast_columns(raw_df, target_table)
            typed_df["_source_file"] = csv_path.name
            typed_df["_ingested_at"] = ingested_at

            fq_table = f"{schema}.{target_table}"
            con.register("staging_df", typed_df)
            con.execute(f"CREATE OR REPLACE TABLE {fq_table} AS SELECT * FROM staging_df;")
            con.unregister("staging_df")

            summary.append(
                {
                    "source_file": csv_path.name,
                    "duckdb_table": fq_table,
                    "rows_ingested": len(typed_df),
                    "columns_count": len(typed_df.columns),
                }
            )
    finally:
        con.close()

    return pd.DataFrame(summary)


if __name__ == "__main__":
    result_df = ingest_csvs_to_duckdb()
    print(result_df.to_string(index=False))