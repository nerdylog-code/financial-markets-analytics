"""
Portfolio 3: Financial Markets / Stock Analysis
Step 2 - Create SQLite DB, load CSV, run stock_analyses.sql, persist results.

Outputs:
  - stock_analytics.db        (SQLite database with stock_prices table)
  - query_results/*.csv       (one CSV per query, for dashboard consumption)
"""
import sqlite3
import csv
import os
import re
from pathlib import Path

OUT_DIR = Path("./03_Financial_Markets")
CSV_IN  = OUT_DIR / "stock_prices.csv"
SQL_IN  = OUT_DIR / "stock_analyses.sql"
DB_PATH = OUT_DIR / "stock_analytics.db"
RES_DIR = OUT_DIR / "query_results"
RES_DIR.mkdir(exist_ok=True)

# Remove old db if present so we always start fresh
if DB_PATH.exists():
    DB_PATH.unlink()

con = sqlite3.connect(DB_PATH)
cur = con.cursor()

# Enforce good types on daily_return so window math works cleanly
cur.execute("""
    CREATE TABLE stock_prices (
        ticker TEXT NOT NULL,
        date   TEXT NOT NULL,
        open   REAL,
        high   REAL,
        low    REAL,
        close  REAL,
        volume INTEGER,
        daily_return REAL,
        market_cap INTEGER
    )
""")
con.commit()

# Load CSV
print(f"Loading {CSV_IN} into SQLite ...")
with open(CSV_IN, "r", encoding="utf-8") as f:
    reader = csv.reader(f)
    next(reader)  # header
    batch = []
    n = 0
    for row in reader:
        # row order: ticker, date, open, high, low, close, volume, daily_return, market_cap
        batch.append((
            row[0], row[1], float(row[2]), float(row[3]), float(row[4]),
            float(row[5]), int(row[6]), float(row[7]), int(row[8])
        ))
        n += 1
        if len(batch) >= 1000:
            cur.executemany("INSERT INTO stock_prices VALUES (?,?,?,?,?,?,?,?,?)", batch)
            batch.clear()
    if batch:
        cur.executemany("INSERT INTO stock_prices VALUES (?,?,?,?,?,?,?,?,?)", batch)

con.commit()

cur.execute("SELECT COUNT(*) FROM stock_prices")
print(f"Loaded {cur.fetchone()[0]:,} rows into stock_prices")

cur.execute("CREATE INDEX IF NOT EXISTS ix_ticker_date ON stock_prices(ticker, date)")
cur.execute("CREATE INDEX IF NOT EXISTS ix_date      ON stock_prices(date)")
con.commit()
print("Indexes created.")

# Split SQL file into individual statements; SQLite native std() won't exist,
# so we register an aggregate for stddev / variance to keep SQL portable.
import statistics

class _Stddev:
    def __init__(self):
        self.v = []
    def step(self, x):
        if x is not None:
            self.v.append(x)
    def finalize(self):
        if len(self.v) < 2:
            return None
        m = sum(self.v) / len(self.v)
        var = sum((x - m) ** 2 for x in self.v) / (len(self.v) - 1)
        return var ** 0.5

# IMPORTANT: pass the *class* itself, not an instance. SQLite constructs
# a fresh instance per aggregate group; passing an instance breaks since
# each step() call mutates the shared state and __init__ is bypassed.
con.create_aggregate("std", 1, _Stddev)
con.create_aggregate("STDDEV", 1, _Stddev)
con.create_aggregate("stddev", 1, _Stddev)

sql_text = SQL_IN.read_text(encoding="utf-8")
# Strip comments
sql_clean = re.sub(r"--[^\n]*", "", sql_text)
# Split on semicolon + newline boundaries
raw_stmts = [s.strip() for s in sql_clean.split(";") if s.strip()]
print(f"\nFound {len(raw_stmts)} statement-level chunks in SQL file")

results = {}
for i, stmt in enumerate(raw_stmts, 1):
    # skip pure comments / blank
    if not stmt:
        continue
    first_line = stmt.strip().splitlines()[0][:80]
    keyword = stmt.lstrip().split(None, 1)[0].upper()
    is_select_like = keyword in ("SELECT", "WITH")
    try:
        cur.execute(stmt)
        if is_select_like:
            rows = cur.fetchall()
            cols = [d[0] for d in cur.description] if cur.description else []
            results[f"Q{i:02d}"] = {
                "sql": stmt,
                "cols": cols,
                "rows": rows,
                "first_line": first_line,
            }
            print(f"  Q{i:02d} OK  -> {len(rows):>6} rows | {first_line}")
            # persist to CSV
            safe = re.sub(r"[^\w]+", "_", first_line)[:40].strip("_") or f"q{i:02d}"
            out_csv = RES_DIR / f"Q{i:02d}_{safe}.csv"
            with open(out_csv, "w", newline="", encoding="utf-8") as f:
                w = csv.writer(f)
                w.writerow(cols)
                w.writerows(rows)
        else:
            con.commit()
            print(f"  Q{i:02d} OK  (DDL) | {first_line}")
    except Exception as e:
        print(f"  Q{i:02d} ERROR: {e}  | {first_line}")

con.commit()
con.close()
print(f"\nSQLite DB:  {DB_PATH}")
print(f"Results dir: {RES_DIR}")
print(f"Queries executed: {len(results)}")
