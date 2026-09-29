# Financial Markets Analytics

SQL + SQLite + Excel dashboard for stock-price and portfolio-style market analysis. Prices are generated with a geometric-Brownian-motion-style process for portfolio practice.

## What is included

- `stock_prices.csv` — daily synthetic prices
- `stock_analytics.db` — SQLite database
- `stock_analyses.sql` — analytical SQL queries
- `Stock_Analytics_Dashboard.xlsx` — Excel dashboard
- Python scripts for data generation and query execution
- `query_results/` — generated analysis outputs

## Skills demonstrated

Moving averages, Golden Cross/Death Cross detection, running maximum drawdown, volatility ranking, correlation analysis, cumulative return and Sharpe-ratio approximation.

## Quick start

1. Open the workbook in Excel.
2. Query `stock_analytics.db` with DB Browser for SQLite.
3. Review and adapt the SQL in `stock_analyses.sql`.
4. Run the Python scripts to reproduce the demo data and outputs.

> Portfolio note: this project is educational and does not provide investment advice or live market data.

## Verificação

```bash
python checks/check_artifacts.py            # confere os artefatos contra o baseline
python checks/check_artifacts.py --update   # regrava o baseline após mudar os dados
```

O baseline em `checks/expected.json` é versionado: se um CSV esvaziar, um banco perder tabela ou uma aba do dashboard desaparecer, a checagem falha. Roda no CI a cada push.
