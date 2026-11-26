from pathlib import Path
import sys
import duckdb

PROJECT_ROOT = Path(__file__).resolve().parents[2]
DB_PATH = PROJECT_ROOT / "data" / "warehouse" / "retailmkt.db"
SQL_DIR = PROJECT_ROOT / "sql" / "analytics"


def resolve_sql_path(arg: str) -> Path:
    candidate = Path(arg)
    if candidate.is_file():
        return candidate

    from_root = PROJECT_ROOT / arg
    if from_root.is_file():
        return from_root

    from_sql_dir = SQL_DIR / arg
    if from_sql_dir.is_file():
        return from_sql_dir

    raise FileNotFoundError(f"SQL file not found: {arg}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python src/utils/run_sql_file.py <path/to/file.sql>")
        sys.exit(1)

    sql_path = resolve_sql_path(sys.argv[1])
    sql = sql_path.read_text(encoding="utf-8")

    con = duckdb.connect(str(DB_PATH))
    try:
        cursor = con.execute(sql)
        if cursor.description is not None:
            print(cursor.df().to_string(index=False))
        else:
            print(f"Executed {sql_path.name}")
    finally:
        con.close()