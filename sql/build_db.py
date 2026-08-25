"""
Loads data/fraud_sample.csv into a local SQLite database (fraudgraph.db)
so all analysis in this project runs off plain SQL.

Usage:
    python sql/build_db.py
"""
import sqlite3
import pandas as pd
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = ROOT / "data" / "fraud_sample.csv"
DB_PATH = ROOT / "data" / "fraudgraph.db"

def main():
    df = pd.read_csv(CSV_PATH)
    conn = sqlite3.connect(DB_PATH)
    df.to_sql("transactions", conn, if_exists="replace", index=False)

    conn.execute("CREATE INDEX IF NOT EXISTS idx_isFraud ON transactions(isFraud)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_card1 ON transactions(card1)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_device ON transactions(DeviceInfo)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_addr1 ON transactions(addr1)")
    conn.commit()
    conn.close()
    print(f"Loaded {len(df):,} rows into {DB_PATH}")

if __name__ == "__main__":
    main()
