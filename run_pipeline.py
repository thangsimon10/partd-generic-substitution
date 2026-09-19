#!/usr/bin/env python3
"""Rebuild the analysis from raw files. Idempotent.

Tuned for a small box (3.8 GB RAM, 4 cores): single-threaded, capped memory,
and it reads only the 12 of 22 CMS columns the analysis uses. Pre-aggregation
in 01_load takes the Orange Book join from tens of millions of rows to tens of
thousands, which is the difference between this running and being OOM-killed.

Raw CSVs are not in the repo (7.4 GB). Download them from the CMS links in
data/source_manifest.md, then point RAW_2023 / RAW_2024 at them.
"""
import duckdb, os, time, sqlutil

RAW_2023 = os.path.expanduser("~/Downloads/MUP_DPR_RY25_P04_V10_DY23_NPIBN.csv")
RAW_2024 = os.path.expanduser("~/Downloads/MUP_DPR_RY26_P04_V10_DY24_NPIBN.csv")
OB       = os.path.expanduser("./data/raw/orange_book/products.txt")
DB       = os.path.expanduser("~/partd.duckdb")

con = duckdb.connect(DB)
for pragma in ("SET memory_limit='2500MB'", "SET threads=1",
               "SET preserve_insertion_order=false"):
    con.execute(pragma)

for step, params in [("sql/01_load.sql",        {"RAW_2023": RAW_2023,
                                                 "RAW_2024": RAW_2024}),
                     ("sql/04_orange_book.sql", {"OB_PRODUCTS": OB}),
                     ("sql/02_metrics.sql",     None)]:
    t0 = time.time()
    sqlutil.run(con, step, params)
    print(f"{step:<26} {time.time()-t0:>6.1f}s")
    con.execute("CHECKPOINT")

print("\nvalidation:")
for check, result, evidence in con.execute(open("sql/03_validation.sql").read()).fetchall():
    print(f"  {check:<56} {result:<34} {evidence}")
