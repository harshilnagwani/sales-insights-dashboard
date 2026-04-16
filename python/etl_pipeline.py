"""
etl_pipeline.py
Sales Insights – Data Analysis Project

ETL Workflow:
  1. Load    → read raw CSV exported from MySQL
  2. Inspect → schema, nulls, distributions
  3. Clean   → remove invalid records, fix currency artifacts
  4. Validate→ assert business rules post-clean
  5. Transform→ currency normalisation, feature engineering
  6. Summary → post-ETL KPI snapshot
  7. Export  → cleaned CSV ready for Power BI / further analysis

Usage:
  pip install pandas numpy
  python python/etl_pipeline.py
"""

import pandas as pd
import numpy as np
import os

# ── Config ──────────────────────────────────────────────────────
RAW_PATH    = "data/sales_sample.csv"
OUTPUT_PATH = "data/sales_cleaned.csv"
USD_TO_INR  = 75  # fixed rate used throughout the project

# Markets outside India scope
INVALID_MARKETS = ["Mark097", "Mark999"]  # Paris, New York


# ── 1. Load ─────────────────────────────────────────────────────────
def load(path: str) -> pd.DataFrame:
    df = pd.read_csv(path, parse_dates=["order_date"])
    print(f"[LOAD]     Rows loaded       : {len(df):,}")
    return df


# ── 2. Inspect ─────────────────────────────────────────────────────
def inspect(df: pd.DataFrame) -> None:
    print(f"\n[INSPECT]  Shape             : {df.shape}")
    nulls = df.isnull().sum()
    if nulls.any():
        print("[INSPECT]  Null counts :\n", nulls[nulls > 0])
    else:
        print("[INSPECT]  Null counts       : none")
    print("[INSPECT]  Currency values  :", df["currency"].unique().tolist())
    print("[INSPECT]  Market codes     :", sorted(df["market_code"].unique().tolist()))
    print("[INSPECT]  sales_amount     :",
          df["sales_amount"].min(), "→", df["sales_amount"].max())
    print("[INSPECT]  Date range       :",
          df["order_date"].min().date(), "→", df["order_date"].max().date())


# ── 3. Clean ───────────────────────────────────────────────────────
def clean(df: pd.DataFrame) -> pd.DataFrame:
    n0 = len(df)

    # 3a. Strip carriage-return artifacts (MySQL dump artifact)
    df["currency"] = df["currency"].str.strip().str.replace("\r", "", regex=False)

    # 3b. Remove zero / negative sales_amount rows
    df = df[df["sales_amount"] > 0].copy()
    print(f"\n[CLEAN]    After ≤0 amount    : {len(df):,} (−{n0 - len(df):,} removed)")

    # 3c. Exclude non-India markets
    n1 = len(df)
    df = df[~df["market_code"].isin(INVALID_MARKETS)].copy()
    print(f"[CLEAN]    After non-India   : {len(df):,} (−{n1 - len(df):,} removed)")

    # 3d. Drop exact duplicate rows
    n2 = len(df)
    df = df.drop_duplicates()
    print(f"[CLEAN]    After dedup       : {len(df):,} (−{n2 - len(df):,} removed)")

    return df


# ── 4. Validate ─────────────────────────────────────────────────────
def validate(df: pd.DataFrame) -> None:
    issues = []
    if (df["sales_amount"] <= 0).any():
        issues.append("❌ Negative/zero sales_amount rows still present")
    if df["order_date"].isnull().any():
        issues.append("❌ Null order_date rows found")
    if df["customer_code"].isnull().any():
        issues.append("❌ Null customer_code rows found")
    unexpected = set(df["currency"].unique()) - {"INR", "USD"}
    if unexpected:
        issues.append(f"❌ Unexpected currency codes: {unexpected}")
    if df["market_code"].isin(INVALID_MARKETS).any():
        issues.append("❌ Non-India markets still present")

    if issues:
        print("\n[VALIDATE] Issues found:")
        for i in issues:
            print(f"  {i}")
    else:
        print("\n[VALIDATE] ✅ All checks passed")


# ── 5. Transform ────────────────────────────────────────────────────
def transform(df: pd.DataFrame) -> pd.DataFrame:
    # 5a. Normalise all amounts to INR
    df["norm_sales_amount"] = np.where(
        df["currency"] == "USD",
        df["sales_amount"] * USD_TO_INR,
        df["sales_amount"]
    )

    # 5b. Normalise profit_margin if column exists
    if "profit_margin" in df.columns:
        df["norm_profit_margin"] = np.where(
            df["currency"] == "USD",
            df["profit_margin"] * USD_TO_INR,
            df["profit_margin"]
        )

    # 5c. Date feature engineering
    df["year"]    = df["order_date"].dt.year
    df["month"]   = df["order_date"].dt.month
    df["quarter"] = df["order_date"].dt.quarter
    df["ym"]      = df["order_date"].dt.to_period("M").astype(str)

    # 5d. Revenue tier classification
    conditions = [
        df["norm_sales_amount"] >= 200_000,
        df["norm_sales_amount"] >= 50_000,
        df["norm_sales_amount"] >= 10_000,
    ]
    choices = ["High (≥2L)", "Medium (50k–2L)", "Low (10k–50k)"]
    df["revenue_tier"] = np.select(conditions, choices, default="Micro (<10k)")

    print(f"\n[TRANSFORM] norm_sales_amount  : created (USD×{USD_TO_INR})")
    print(f"[TRANSFORM] Date features      : year, month, quarter, ym")
    print(f"[TRANSFORM] Revenue tiers      :")
    print(df["revenue_tier"].value_counts().to_string())

    return df


# ── 6. Summary ─────────────────────────────────────────────────────
def summary(df: pd.DataFrame) -> None:
    total_rev = df["norm_sales_amount"].sum()
    total_qty = df["sales_qty"].sum()
    print("\n" + "="*58)
    print(" POST-ETL SUMMARY")
    print("="*58)
    print(f" Clean records      : {len(df):,}")
    print(f" Date range         : {df['order_date'].min().date()} → {df['order_date'].max().date()}")
    print(f" Total revenue (INR): ₹{total_rev:,.0f}")
    print(f" Total sales qty    : {total_qty:,}")
    print(f" Unique customers   : {df['customer_code'].nunique()}")
    print(f" Unique markets     : {df['market_code'].nunique()}")
    print(f" Unique products    : {df['product_code'].nunique()}")
    if "norm_profit_margin" in df.columns:
        total_pm = df["norm_profit_margin"].sum()
        pct = total_pm / total_rev * 100
        print(f" Total profit margin: ₹{total_pm:,.0f} ({pct:.1f}%)")
    print("="*58)


# ── 7. Export ──────────────────────────────────────────────────────
def export(df: pd.DataFrame, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True) if os.path.dirname(path) else None
    df.to_csv(path, index=False)
    print(f"\n[EXPORT]   Saved → {path}")


# ── Main ─────────────────────────────────────────────────────────
if __name__ == "__main__":
    df = load(RAW_PATH)
    inspect(df)
    df = clean(df)
    validate(df)
    df = transform(df)
    summary(df)
    export(df, OUTPUT_PATH)
