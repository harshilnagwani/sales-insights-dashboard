-- ============================================================
-- Sales Insights – Data Analysis Project
-- Exploratory & Analytical SQL Queries
-- Database : sales (MySQL 8.0)
-- Tables   : customers, transactions, markets, products, date
-- ============================================================

-- ── 1. BASIC EXPLORATION ──────────────────────────────────────────────────

SELECT * FROM customers;
SELECT COUNT(*) AS total_customers FROM customers;

SELECT * FROM transactions LIMIT 100;
SELECT COUNT(*) AS total_transactions FROM transactions;

-- Transactions in Delhi NCR (Mark004)
SELECT * FROM transactions WHERE market_code = 'Mark004';

-- Distinct products sold in Delhi NCR
SELECT DISTINCT product_code FROM transactions WHERE market_code = 'Mark004';

-- USD-denominated transactions (handles MySQL \r artifact)
SELECT * FROM transactions
WHERE currency IN ('USD', 'USD\r');


-- ── 2. DATA QUALITY CHECKS ─────────────────────────────────────────────

-- Invalid / zero-amount transactions
SELECT COUNT(*) AS invalid_records
FROM transactions
WHERE sales_amount <= 0;

-- Currency distribution (exposes \r artifacts)
SELECT currency, COUNT(*) AS cnt
FROM transactions
GROUP BY currency
ORDER BY cnt DESC;

-- Null checks on key columns
SELECT
    SUM(CASE WHEN sales_amount   IS NULL THEN 1 ELSE 0 END) AS null_amount,
    SUM(CASE WHEN customer_code  IS NULL THEN 1 ELSE 0 END) AS null_customer,
    SUM(CASE WHEN order_date     IS NULL THEN 1 ELSE 0 END) AS null_date,
    SUM(CASE WHEN market_code    IS NULL THEN 1 ELSE 0 END) AS null_market
FROM transactions;

-- Markets with missing zone (non-India markets to exclude)
SELECT DISTINCT markets_code, markets_name, zone
FROM markets
WHERE zone IS NULL OR zone = '';


-- ── 3. REVENUE ANALYSIS ────────────────────────────────────────────────

-- Total revenue (normalised: USD × 75 → INR)
SELECT
    SUM(CASE
        WHEN currency IN ('USD', 'USD\r') THEN sales_amount * 75
        ELSE sales_amount
    END) AS total_revenue_inr
FROM transactions
WHERE sales_amount > 0;

-- Revenue by year
SELECT
    d.year,
    SUM(CASE
        WHEN t.currency IN ('USD', 'USD\r') THEN t.sales_amount * 75
        ELSE t.sales_amount
    END)                    AS revenue_inr
FROM transactions t
INNER JOIN date d ON t.order_date = d.date
WHERE t.sales_amount > 0
GROUP BY d.year
ORDER BY d.year;

-- Revenue by year-month
SELECT
    d.year,
    d.month_name,
    d.cy_date                                                           AS month_start,
    SUM(CASE
        WHEN t.currency IN ('USD', 'USD\r') THEN t.sales_amount * 75
        ELSE t.sales_amount
    END)                                                                AS revenue_inr,
    SUM(t.sales_qty)                                                    AS total_qty
FROM transactions t
INNER JOIN date d ON t.order_date = d.date
WHERE t.sales_amount > 0
GROUP BY d.year, d.month_name, d.cy_date
ORDER BY d.cy_date;

-- Revenue by market (with zone)
SELECT
    m.markets_name  AS market,
    m.zone,
    SUM(CASE
        WHEN t.currency IN ('USD', 'USD\r') THEN t.sales_amount * 75
        ELSE t.sales_amount
    END)            AS revenue_inr,
    SUM(t.sales_qty) AS total_qty,
    ROUND(SUM(t.profit_margin), 2) AS total_profit
FROM transactions t
INNER JOIN markets m ON t.market_code = m.markets_code
WHERE t.sales_amount > 0
GROUP BY m.markets_name, m.zone
ORDER BY revenue_inr DESC;


-- ── 4. PROFIT ANALYSIS ─────────────────────────────────────────────────

-- Overall profit margin %
SELECT
    ROUND(
        SUM(profit_margin) / SUM(sales_amount) * 100,
    2) AS overall_profit_margin_pct
FROM transactions
WHERE sales_amount > 0;

-- Profit % by market
SELECT
    m.markets_name AS market,
    ROUND(SUM(t.profit_margin) / SUM(t.sales_amount) * 100, 2) AS profit_margin_pct
FROM transactions t
INNER JOIN markets m ON t.market_code = m.markets_code
WHERE t.sales_amount > 0
GROUP BY m.markets_name
ORDER BY profit_margin_pct DESC;

-- Loss-making markets (negative profit margin)
SELECT
    m.markets_name,
    ROUND(SUM(t.profit_margin) / SUM(t.sales_amount) * 100, 2) AS profit_margin_pct
FROM transactions t
INNER JOIN markets m ON t.market_code = m.markets_code
WHERE t.sales_amount > 0
GROUP BY m.markets_name
HAVING profit_margin_pct < 0
ORDER BY profit_margin_pct;


-- ── 5. CUSTOMER ANALYSIS ───────────────────────────────────────────────

-- Top 10 customers by revenue
SELECT
    c.custmer_name      AS customer,
    c.customer_type,
    SUM(CASE
        WHEN t.currency IN ('USD', 'USD\r') THEN t.sales_amount * 75
        ELSE t.sales_amount
    END)                AS revenue_inr,
    ROUND(SUM(t.profit_margin) / SUM(t.sales_amount) * 100, 2) AS profit_margin_pct
FROM transactions t
INNER JOIN customers c ON t.customer_code = c.customer_code
WHERE t.sales_amount > 0
GROUP BY c.custmer_name, c.customer_type
ORDER BY revenue_inr DESC
LIMIT 10;

-- Revenue contribution % by customer
SELECT
    c.custmer_name AS customer,
    ROUND(
        SUM(CASE WHEN t.currency IN ('USD','USD\r') THEN t.sales_amount*75 ELSE t.sales_amount END)
        * 100.0
        / (SELECT SUM(CASE WHEN currency IN ('USD','USD\r') THEN sales_amount*75 ELSE sales_amount END)
           FROM transactions WHERE sales_amount > 0),
    2) AS revenue_contribution_pct
FROM transactions t
INNER JOIN customers c ON t.customer_code = c.customer_code
WHERE t.sales_amount > 0
GROUP BY c.custmer_name
ORDER BY revenue_contribution_pct DESC
LIMIT 10;

-- Revenue split: Brick & Mortar vs E-Commerce
SELECT
    c.customer_type,
    SUM(CASE
        WHEN t.currency IN ('USD', 'USD\r') THEN t.sales_amount * 75
        ELSE t.sales_amount
    END) AS revenue_inr
FROM transactions t
INNER JOIN customers c ON t.customer_code = c.customer_code
WHERE t.sales_amount > 0
GROUP BY c.customer_type;


-- ── 6. PRODUCT ANALYSIS ────────────────────────────────────────────────

-- Top 10 products by revenue
SELECT
    t.product_code,
    p.product_type,
    SUM(CASE
        WHEN t.currency IN ('USD', 'USD\r') THEN t.sales_amount * 75
        ELSE t.sales_amount
    END)             AS revenue_inr,
    SUM(t.sales_qty) AS total_qty
FROM transactions t
INNER JOIN products p ON t.product_code = p.product_code
WHERE t.sales_amount > 0
GROUP BY t.product_code, p.product_type
ORDER BY revenue_inr DESC
LIMIT 10;
