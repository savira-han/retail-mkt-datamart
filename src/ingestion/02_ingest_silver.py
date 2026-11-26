from pathlib import Path
import time
import duckdb

PROJECT_ROOT = Path(__file__).resolve().parents[2]
DB_PATH = PROJECT_ROOT / "data" / "warehouse" / "retailmkt.db"
SQL_FILE = PROJECT_ROOT / "sql" / "silver" / "00_build_all_silver.sql"


def main() -> None:
    if not DB_PATH.exists():
        raise FileNotFoundError(f"DuckDB database not found: {DB_PATH}")
    if not SQL_FILE.exists():
        raise FileNotFoundError(f"SQL file not found: {SQL_FILE}")

    sql = SQL_FILE.read_text(encoding="utf-8")
    start_time = time.perf_counter()

    con = duckdb.connect(str(DB_PATH))
    try:
        con.execute(sql)
    finally:
        con.close()

    elapsed = time.perf_counter() - start_time
    print(f"Silver layer built from {SQL_FILE.relative_to(PROJECT_ROOT)} in {elapsed:.2f}s.")


if __name__ == "__main__":
    main()