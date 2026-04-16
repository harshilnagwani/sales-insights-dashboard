# 🗄️ SQL Query Reference — Sales Insights

All queries are **MySQL 8.0-compatible**. The file is organised into 6 sections covering the full analytical workflow.

---

## 📋 Table Schemas

### `transactions`
| Column | Type | Description |
|--------|------|-------------|
| `product_code` | VARCHAR | Product identifier |
| `customer_code` | VARCHAR | Customer identifier |
| `market_code` | VARCHAR | Market identifier |
| `order_date` | DATE | Transaction date |
| `sales_qty` | INT | Units sold |
| `sales_amount` | DECIMAL | Sale value (INR or USD) |
| `currency` | VARCHAR | `INR`, `USD` (may contain `\r` artifact) |
| `profit_margin_percentage` | DECIMAL | Profit as fraction of sale |
| `profit_margin` | DECIMAL | Absolute profit in transaction currency |
| `cost_price` | DECIMAL | Cost of goods |

### `customers`
| Column | Type | Description |
|--------|------|-------------|
| `customer_code` | VARCHAR | PK |
| `custmer_name` | VARCHAR | Customer name |
| `customer_type` | VARCHAR | `Brick & Mortar` / `E-Commerce` |

### `markets`
| Column | Type | Description |
|--------|------|-------------|
| `markets_code` | VARCHAR | PK |
| `markets_name` | VARCHAR | City name |
| `zone` | VARCHAR | `North` / `South` / `Central` (NULL for Paris, New York) |

### `products`
| Column | Type | Description |
|--------|------|-------------|
| `product_code` | VARCHAR | PK |
| `product_type` | VARCHAR | `Own Brand` / `Distribution` |

### `date`
| Column | Type | Description |
|--------|------|-------------|
| `date` | DATE | PK — joins to `transactions.order_date` |
| `cy_date` | DATE | Calendar year date (month start) |
| `year` | INT | Year |
| `month_name` | VARCHAR | Month name |
| `date_yy_mmm` | VARCHAR | Formatted label (e.g., `Jan 2020`) |

---

## 🔍 Query Index

| # | Section | Techniques Used |
|---|---------|------------------|
| 1 | Basic Exploration | `SELECT *`, `COUNT`, `DISTINCT`, `LIMIT` |
| 2 | Data Quality Checks | `CASE WHEN`, `IS NULL`, `GROUP BY`, `HAVING` |
| 3 | Revenue Analysis | Multi-table `INNER JOIN`, `CASE` currency normalisation, `GROUP BY`, `ORDER BY` |
| 4 | Profit Analysis | Derived aggregation, `HAVING` for loss-making filter |
| 5 | Customer Analysis | Correlated subquery for contribution %, `INNER JOIN`, `LIMIT` |
| 6 | Product Analysis | Multi-table `JOIN`, revenue + quantity aggregation |

---

## ▶️ How to Run

```bash
# 1. Restore database
mysql -u root -p -e "CREATE DATABASE sales;"
mysql -u root -p sales < db_dump_version_2.sql

# 2. Run all queries
mysql -u root -p sales < sql/sales_analysis_queries.sql
```

> 💡 **Note on currency artifact:** MySQL dumps can add `\r` (carriage return) to VARCHAR values. Queries handle this via `IN ('USD', 'USD\r')`. The Python ETL strips it at source before loading to Power BI.
