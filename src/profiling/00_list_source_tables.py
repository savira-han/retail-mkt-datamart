from pathlib import Path
import pandas as pd

raw_dir = Path(__file__).resolve().parents[2] / "data" / "raw"

COLUMNS = [
    "file_name",
    "stem",
    "size_mb",
    "row_count",
    "column_count",
]

#function to get rows and columns count
def get_csv_shape(file_path: Path) -> tuple[int | None, int | None]:
    try:
        df = pd.read_csv(file_path)
        return len(df), len(df.columns)
    except Exception as exc:
        print(f"Could not read file {file_path.name}: {exc}")
        return None, None

#get other informations from the datasource (size)
def get_raw_csv_df(directory: Path) -> pd.DataFrame:
    if not directory.is_dir():
        raise FileNotFoundError(f"Raw data directory not found: {directory}")

    records: list[dict[str, object]] = []
    for entry in sorted(directory.iterdir()):
        if (
            entry.is_file()
            and not entry.name.startswith(".")
            and entry.suffix.lower() == ".csv"
        ):
            try:
                size_bytes = entry.stat().st_size
            except OSError as exc:
                print(f"Skipping {entry.name}: {exc}")
                continue

            row_count, column_count = get_csv_shape(entry)
            records.append(
                {
                    "file_name": entry.name,
                    "stem": entry.stem,
                    "size_mb": round(size_bytes / (1024**2), 2),
                    "row_count": row_count if row_count is not None else pd.NA,
                    "column_count": column_count if column_count is not None else pd.NA,
                }
            )

    df = pd.DataFrame(records, columns=COLUMNS)
    dtypes = {
        "file_name": "string",
        "stem": "string",
        "size_mb": "float64",
        "row_count": "Int64",
        "column_count": "Int64",
    }
    if df.empty:
        return df.astype(dtypes)

    return (
        df.astype(dtypes)
        .sort_values("size_mb", ascending=False)
        .reset_index(drop=True)
    )

#hange the formatting for row count to be easier to read
def format_counts_display(df: pd.DataFrame) -> pd.DataFrame:
    display_df = df.copy()
    display_df["row_count"] = display_df["row_count"].map(
        lambda v: f"{v:,}" if pd.notna(v) else ""
    )
    return display_df


if __name__ == "__main__":
    df_raw_csvs = get_raw_csv_df(raw_dir)
    print(format_counts_display(df_raw_csvs).to_string(index=False))