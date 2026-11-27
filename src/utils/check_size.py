
from pathlib import Path
import pandas as pd

# Project root
PROJECT_ROOT = Path(__file__).resolve().parents[2]

# Processed data directory
DATA_DIR = PROJECT_ROOT / "data" / "processed"

# Get all CSV files
csv_files = list(DATA_DIR.glob("*.csv"))

# Collect file information
results = []

for file in csv_files:
    size_mb = file.stat().st_size / (1024 ** 2)

    results.append({
        "file_name": file.name,
        "size_mb": round(size_mb, 2)
    })

# Create DataFrame
df = pd.DataFrame(results)

# Sort by size, largest first
df = df.sort_values("size_mb", ascending=False)

# Display results
print(df.to_string(index=False))

# Total size
print(f"\nTotal CSV files: {len(df)}")
print(f"Total size: {df['size_mb'].sum():,.2f} MB")
