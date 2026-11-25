from pathlib import Path
import pandas as pd

raw_dir = Path(__file__).resolve().parents[2] / "data" / "raw"

OUTPUT_COLUMNS = [
    "table_name",
    "column_name",
    "data type",
    "count_rows",
    "unique_values",
    "missing_values",
    "missing_values_pct",
    "min_value",
    "max_value",
    "avg_value",
    "possible_key",
]

READABLE_COLUMNS = [
    "count_rows",
    "unique_values",
    "missing_values",
    "missing_values_pct",
    "min_value",
    "max_value",
    "avg_value",
]


def format_number(val: object, decimals: int = 2) -> str:
    if val is None or pd.isna(val):
        return ""
    if isinstance(val, bool):
        return str(val)
    if isinstance(val, (int, pd.Int64Dtype.type)):
        return f"{int(val):,}"
    if isinstance(val, (float, pd.Float64Dtype.type)):
        if float(val).is_integer():
            return f"{int(val):,}"
        return f"{float(val):,.{decimals}f}"
    return str(val)


def format_pct(val: object, decimals: int = 2) -> str:
    if val is None or pd.isna(val):
        return ""
    return f"{float(val):,.{decimals}f}%"


def format_readable_df(df: pd.DataFrame) -> pd.DataFrame:
    formatted = df.copy()
    for col in READABLE_COLUMNS:
        if col not in formatted.columns:
            continue
        if col == "missing_values_pct":
            formatted[col] = formatted[col].map(lambda v: format_pct(v, decimals=2))
        else:
            formatted[col] = formatted[col].map(lambda v: format_number(v, decimals=2))
    return formatted


def load_datasource(file_path: Path) -> pd.DataFrame:
    ext = file_path.suffix.lower()
    if ext == ".csv":
        return pd.read_csv(file_path)
    if ext == ".tsv":
        return pd.read_csv(file_path, sep="\t")
    if ext == ".parquet":
        return pd.read_parquet(file_path)
    if ext in {".xlsx", ".xls"}:
        return pd.read_excel(file_path)
    if ext == ".jsonl":
        return pd.read_json(file_path, lines=True)
    if ext == ".json":
        return pd.read_json(file_path)
    raise ValueError(f"Unsupported file extension: {file_path.suffix}")


def profile_dataframe(df: pd.DataFrame, table_name: str) -> list[dict[str, object]]:
    total_rows = len(df)
    rows: list[dict[str, object]] = []

    for col in df.columns:
        series = df[col]
        missing_count = int(series.isna().sum())
        missing_pct = (
            round((missing_count / total_rows) * 100, 2) if total_rows > 0 else 0.0
        )
        unique_count = int(series.nunique(dropna=True))
        possible_key = bool(
            total_rows > 0 and missing_count == 0 and unique_count == total_rows
        )

        if pd.api.types.is_numeric_dtype(series):
            non_null = series.dropna()
            min_val = non_null.min() if not non_null.empty else pd.NA
            max_val = non_null.max() if not non_null.empty else pd.NA
            avg_val = (
                round(float(non_null.mean()), 2) if not non_null.empty else pd.NA
            )
        else:
            min_val = pd.NA
            max_val = pd.NA
            avg_val = pd.NA

        rows.append(
            {
                "table_name": table_name,
                "column_name": col,
                "data type": str(series.dtype),
                "count_rows": total_rows,
                "unique_values": unique_count,
                "missing_values": missing_count,
                "missing_values_pct": missing_pct,
                "min_value": min_val,
                "max_value": max_val,
                "avg_value": avg_val,
                "possible_key": possible_key,
            }
        )

    return rows


def profile_all_raw_datasources(
    directory: Path, readable: bool = True
) -> pd.DataFrame:
    if not directory.is_dir():
        raise FileNotFoundError(f"Raw data directory not found: {directory}")

    all_rows: list[dict[str, object]] = []

    for entry in sorted(directory.iterdir()):
        if not entry.is_file() or entry.name.startswith("."):
            continue
        try:
            df = load_datasource(entry)
            all_rows.extend(profile_dataframe(df, table_name=entry.stem))
        except Exception as exc:
            print(f"Skipping {entry.name}: {exc}")
            continue

    summary_df = pd.DataFrame(all_rows, columns=OUTPUT_COLUMNS)
    return format_readable_df(summary_df) if readable else summary_df


if __name__ == "__main__":
    summary_df = profile_all_raw_datasources(raw_dir, readable=True)
    print(summary_df.to_string(index=False))