"""
Portfolio 3: Financial Markets / Stock Analysis
Step 1 - Generate realistic stock price dataset via Geometric Brownian Motion.

10 tickers, 5 years daily data (2020-2024, ~252 trading days/year).
Columns: ticker, date, open, high, low, close, volume, daily_return, market_cap
Output:  stock_prices.csv  (~12,600 rows)
"""
import numpy as np
import pandas as pd
from datetime import datetime

np.random.seed(42)

OUT_DIR = "./03_Financial_Markets"
CSV_PATH = f"{OUT_DIR}/stock_prices.csv"

# Realistic starting prices (approx Jan 2020) and annual drift/vol approximations
# (mu = annual expected return, sigma = annual volatility)
STOCKS = {
    # ticker: (start_price, mu, sigma, shares_outstanding_millions, name)
    "AAPL": (75.0,  0.30, 0.32, 16000, "Apple Inc."),
    "MSFT": (160.0, 0.25, 0.28,  7500, "Microsoft Corp."),
    "GOOGL":(1350.0,0.22, 0.30,   650, "Alphabet Inc."),
    "AMZN": (1850.0,0.28, 0.35,   500, "Amazon.com Inc."),
    "TSLA": ( 28.0, 0.55, 0.65,  3800, "Tesla Inc."),
    "META": (210.0, 0.25, 0.38,  2400, "Meta Platforms Inc."),
    "NVDA": ( 60.0, 0.45, 0.50,  2450, "NVIDIA Corp."),
    "JPM":  (140.0, 0.12, 0.27,  3000, "JPMorgan Chase & Co."),
    "JNJ":  (155.0, 0.08, 0.18,  2600, "Johnson & Johnson"),
    "V":    (210.0, 0.15, 0.24,  1600, "Visa Inc."),
}

# Trading days: simulate ~252 per year x 5 years = 1260
TRADING_DAYS_PER_YEAR = 252
YEARS = 5
N_DAYS = TRADING_DAYS_PER_YEAR * YEARS  # 1260
DT = 1.0 / TRADING_DAYS_PER_YEAR

# Build a business-day calendar from 2020-01-02 onwards
start_date = pd.Timestamp("2020-01-02")
all_dates = pd.bdate_range(start=start_date, periods=N_DAYS)
print(f"Generating {N_DAYS} trading days from {all_dates[0].date()} to {all_dates[-1].date()}")

all_rows = []
for ticker, (s0, mu, sigma, shares_m, name) in STOCKS.items():
    # Geometric Brownian Motion: S_t = S_{t-1} * exp((mu - 0.5*sigma^2)*dt + sigma*sqrt(dt)*Z)
    Z = np.random.standard_normal(N_DAYS)
    drift = (mu - 0.5 * sigma**2) * DT
    shock = sigma * np.sqrt(DT) * Z
    log_returns = drift + shock

    # Prices via cumulative product of exp(log_returns)
    prices = np.empty(N_DAYS)
    prices[0] = s0
    for t in range(1, N_DAYS):
        prices[t] = prices[t - 1] * np.exp(log_returns[t])

    # Daily simple returns
    daily_returns = np.empty(N_DAYS)
    daily_returns[0] = 0.0
    for t in range(1, N_DAYS):
        daily_returns[t] = prices[t] / prices[t - 1] - 1.0

    # Volume: lognormal-ish random, ticker-specific baseline + noise + occasional spikes
    base_vol = np.random.uniform(15_000_000, 120_000_000)
    vol_noise = np.random.lognormal(mean=np.log(base_vol), sigma=0.6, size=N_DAYS)
    # Clip to [10M, 400M]
    volume = np.clip(vol_noise, 10_000_000, 400_000_000).astype(np.int64)
    # Random spike days (3% of days) -> up to 3x volume
    spike_mask = np.random.random(N_DAYS) < 0.03
    volume[spike_mask] = np.minimum(volume[spike_mask] * 3, 400_000_000)

    # OHLC from close: open = prev close * small noise; high/low around the day range
    close = prices
    open_ = np.empty(N_DAYS)
    open_[0] = s0
    open_[1:] = prices[:-1] * (1.0 + np.random.normal(0, 0.005, size=N_DAYS - 1))
    intraday_range = np.abs(np.random.normal(0, 0.012, size=N_DAYS))  # ~1.2% range
    high = np.maximum(open_, close) * (1.0 + intraday_range)
    low = np.minimum(open_, close) * (1.0 - intraday_range)

    # Market cap = close * shares (in $)
    market_cap = close * shares_m * 1_000_000

    df = pd.DataFrame({
        "ticker": ticker,
        "date": all_dates.strftime("%Y-%m-%d"),
        "open": np.round(open_, 4),
        "high": np.round(high, 4),
        "low": np.round(low, 4),
        "close": np.round(close, 4),
        "volume": volume,
        "daily_return": np.round(daily_returns, 6),
        "market_cap": np.round(market_cap, 0).astype(np.int64),
    })
    all_rows.append(df)

full = pd.concat(all_rows, ignore_index=True)
full.to_csv(CSV_PATH, index=False)
print(f"\nCSV saved: {CSV_PATH}")
print(f"Rows: {len(full):,}  | Columns: {list(full.columns)}")
print(f"Tickers: {full['ticker'].nunique()}  | Date range: {full['date'].min()} -> {full['date'].max()}")
print("\nFinal closing prices by ticker:")
print(full.groupby('ticker')['close'].agg(['first', 'last', 'mean']).round(2))
print("\nSample rows:")
print(full.head(8).to_string(index=False))
