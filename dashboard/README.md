# 📊 Power BI Dashboard — Sales Insights

Interactive 3-page dashboard built on the cleaned `sales_cleaned.csv` output from the Python ETL pipeline, connected live to `localhost/sales` MySQL database.

---

## 🗂️ Dashboard Pages

### Page 1 — Revenue Overview
![Revenue Overview](overview.jpg)

**KPI Cards:** Total Revenue (₹142M) · Sales Qty (350K) · Total Profit Margin (₹2.1M)

**Visuals:**
- Revenue Contribution % by Market (bar) — Delhi NCR dominates at 54.7%
- Profit Contribution % by Market (bar) — Mumbai leads at 23.9%
- Profit % by Market (bar, sorted) — Bhubaneshwar highest at 10.5%, Lucknow negative at −2.7%
- Monthly Revenue Trend (line, Jan 2017 – Jun 2020)
- Customer-level table: Revenue, Revenue Contribution %, Profit Margin Contribution %, Profit Margin %

---

### Page 2 — Profit Analysis
![Profit Analysis](profit_analysis.jpg)

**Slicers:** Year (2017–2020) · Month · Dynamic Profit Target (slider)

**Visuals:**
- Revenue Contribution % by Market (bar) — coloured Red/Blue based on Profit Target threshold
- Revenue Trend: Revenue LY (grey) vs Revenue (blue) vs Profit Margin % (orange line) — combo chart
- Customer-level table with full KPI breakdown

---

### Page 3 — Performance Insights
![Performance Insights](performance_insights.jpg)

**KPI Cards:** Revenue · Sales Qty

**Visuals:**
- Revenue by Markets (bar)
- Sales Qty by Markets (bar)
- Top 5 Customers by Revenue (bar, purple)
- Top 5 Products by Revenue (bar, purple)

---

## 🧠 DAX Measures

```dax
-- Total Revenue (INR normalised)
Revenue = 
    SUMX(
        transactions,
        IF(
            OR(transactions[currency] = "USD", transactions[currency] = "USD" & UNICHAR(13)),
            transactions[sales_amount] * 75,
            transactions[sales_amount]
        )
    )

-- Revenue Same Period Last Year
Revenue LY = 
    CALCULATE([Revenue], SAMEPERIODLASTYEAR('date'[date]))

-- Total Profit Margin
Profit Margin Total = SUM(transactions[profit_margin])

-- Profit Margin %
Profit Margin % = DIVIDE([Profit Margin Total], [Revenue], 0)

-- Revenue Contribution % (market/customer level)
Revenue Contribution % = 
    DIVIDE(
        [Revenue],
        CALCULATE([Revenue], ALL(markets), ALL(customers)),
        0
    )

-- Profit Margin Contribution %
Profit Margin Contribution % = 
    DIVIDE(
        [Profit Margin Total],
        CALCULATE([Profit Margin Total], ALL(markets), ALL(customers)),
        0
    )

-- Dynamic Profit Target (used with What-If parameter)
Profit Target = 'Profit Target'[Profit Target Value]
```

---

## 🎯 Business Value

- Identifies **loss-making markets** (Lucknow at −2.7%) for immediate strategic review
- Flags **single-customer dependency risk** — Electricalsara Stores = 46.2% of revenue
- Revenue LY overlay reveals YoY performance decline starting Q1 2020
- Profit Target slicer enables the Sales Director to dynamically identify underperforming markets
