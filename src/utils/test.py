import duckdb
from pathlib import Path

ROOT_DIR = Path.cwd()

db_files = [
    ROOT_DIR / "retailmkt.db",
    ROOT_DIR / "data" / "warehouse" / "retailmkt.db"
]

for db_path in db_files:
    if not db_path.exists():
        continue

    print(f"\nDatabase: {db_path}")

    con = duckdb.connect(str(db_path), read_only=True)

    tables = con.execute("""
        SELECT table_schema, COUNT(*)
        FROM information_schema.tables
        GROUP BY table_schema
        ORDER BY table_schema
    """).fetchall()

    print(tables)

    con.close()