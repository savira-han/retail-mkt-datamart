from pathlib import Path
import sys
import duckdb
import pandas as pd

PROJECT_ROOT = Path(__file__).resolve().parents[2]
DB_PATH = PROJECT_ROOT / "data" / "warehouse" / "retailmkt.db"

LIST_TABLES_SQL = """

SELECT
    table_schema,
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema NOT IN ('information_schema', 'pg_catalog')
and table_schema = 'gold'
ORDER BY table_schema, table_name;


"""

# SELECT
#     table_name,
#     column_name,
#     data_type
# FROM information_schema.columns
# WHERE table_schema = 'gold'
# ORDER BY table_name, ordinal_position;

# SELECT
#     table_schema,
#     table_name,
#     table_type
# FROM information_schema.tables
# WHERE table_schema NOT IN ('information_schema', 'pg_catalog')
# ORDER BY table_schema, table_name;


def run_query(
    sql: str = LIST_TABLES_SQL,
    db_path: Path = DB_PATH,
    read_only: bool = True,
) -> pd.DataFrame | None:
    if not db_path.exists():
        raise FileNotFoundError(f"DuckDB database not found: {db_path}")

    con = duckdb.connect(str(db_path), read_only=read_only)
    try:
        cleaned = sql.strip()
        if not cleaned:
            return None

        cursor = con.execute(cleaned)
        if cursor.description is not None:
            return cursor.df()
        return None
    finally:
        con.close()


def resolve_sql_input(args: list[str]) -> str:
    if not args:
        return LIST_TABLES_SQL

    target = " ".join(args).strip()
    candidate_path = Path(target)
    if candidate_path.is_file():
        return candidate_path.read_text(encoding="utf-8")
    return target


if __name__ == "__main__":
    sql_to_run = resolve_sql_input(sys.argv[1:])
    result = run_query(sql=sql_to_run, read_only=True)

    if result is not None:
        print(result.to_string(index=False))
    else:
        print("Query executed successfully (no result set returned).")