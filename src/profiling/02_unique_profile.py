from pathlib import Path
import pandas as pd

raw_dir = Path(__file__).resolve().parents[2] / "data" / "raw"

OUTPUT_COLUMNS = [
    "table_name",
    "duplicated_rows",
    "count_rows",
    "duplicated_pct",
]


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


def format_int(val: int) -> str:
    return f"{int(val):,}"


def format_pct(val: float, decimals: int = 2) -> str:
    return f"{float(val):,.{decimals}f}%"


def format_readable_df(df: pd.DataFrame) -> pd.DataFrame:
    formatted = df.copy()
    if "duplicated_rows" in formatted.columns:
        formatted["duplicated_rows"] = formatted["duplicated_rows"].map(format_int)
    if "count_rows" in formatted.columns:
        formatted["count_rows"] = formatted["count_rows"].map(format_int)
    if "duplicated_pct" in formatted.columns:
        formatted["duplicated_pct"] = formatted["duplicated_pct"].map(
            lambda v: format_pct(v, decimals=2)
        )
    return formatted


def profile_table_duplicates(df: pd.DataFrame, table_name: str) -> dict[str, object]:
    count_rows = len(df)
    if count_rows > 0:
        try:
            duplicated_rows = int(df.duplicated(keep="first").sum())
        except TypeError:
            hashable_cols = [
                col
                for col in df.columns
                if df[col].map(lambda x: isinstance(x, (dict, list, set))).sum() == 0
            ]
            duplicated_rows = (
                int(df[hashable_cols].duplicated(keep="first").sum())
                if hashable_cols
                else 0
            )
        duplicated_pct = (duplicated_rows / count_rows) * 100
    else:
        duplicated_rows = 0
        duplicated_pct = 0.0

    return {
        "table_name": table_name,
        "duplicated_rows": duplicated_rows,
        "count_rows": count_rows,
        "duplicated_pct": duplicated_pct,
    }


def profile_all_datasources(
    directory: Path, readable: bool = True
) -> pd.DataFrame:
    if not directory.is_dir():
        raise FileNotFoundError(f"Raw data directory not found: {directory}")

    records: list[dict[str, object]] = []
    for entry in sorted(directory.iterdir()):
        if not entry.is_file() or entry.name.startswith("."):
            continue
        try:
            df = load_datasource(entry)
            records.append(profile_table_duplicates(df, table_name=entry.stem))
        except Exception as exc:
            print(f"Skipping {entry.name}: {exc}")
            continue

    summary_df = pd.DataFrame(records, columns=OUTPUT_COLUMNS)
    return format_readable_df(summary_df) if readable else summary_df


if __name__ == "__main__":
    dup_df = profile_all_datasources(raw_dir, readable=True)
    print(dup_df.to_string(index=False))