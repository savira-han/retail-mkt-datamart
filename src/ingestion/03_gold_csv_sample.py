
import duckdb
from pathlib import Path

# --------------------------------------------------
# 1. Define project paths
# --------------------------------------------------

# Project root = two levels above this script
PROJECT_ROOT = Path(__file__).resolve().parents[2]

DB_PATH = PROJECT_ROOT / "data" / "warehouse" / "retailmkt.db"
OUTPUT_DIR = PROJECT_ROOT / "data" / "processed_sample"

print(f"Project root: {PROJECT_ROOT}")
print(f"Database: {DB_PATH}")
print(f"Output directory: {OUTPUT_DIR}")

# --------------------------------------------------
# 2. Validate paths
# --------------------------------------------------

if not DB_PATH.exists():
    raise FileNotFoundError(
        f"Database not found: {DB_PATH}"
    )

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# --------------------------------------------------
# 3. Connect to DuckDB
# --------------------------------------------------

con = duckdb.connect(str(DB_PATH), read_only=True)

try:
    # Retrieve all Gold tables
    tables = con.execute("""
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'gold'
          AND table_type = 'BASE TABLE'
        ORDER BY table_name
    """).fetchall()

    if not tables:
        print("No tables found in the Gold schema.")

    else:
        print(f"\nFound {len(tables)} Gold tables.")
        print("\nStarting CSV export...\n")

        # --------------------------------------------------
        # 4. Export each table to CSV
        # --------------------------------------------------

        for (table_name,) in tables:

            output_path = OUTPUT_DIR / f"sample_{table_name}.csv"

            # Escape SQL identifiers and file path
            safe_table_name = table_name.replace('"', '""')
            safe_output_path = str(output_path).replace("'", "''")

            con.execute(f"""
                COPY (
                    SELECT *
                    FROM gold."{safe_table_name}"
                    USING SAMPLE 1000 ROWS
                )
                TO '{safe_output_path}'
                (FORMAT CSV, HEADER TRUE);
            """)

            print(f"Exported: {table_name}.csv")

        print("\nCSV export completed successfully.")

finally:
    con.close()
