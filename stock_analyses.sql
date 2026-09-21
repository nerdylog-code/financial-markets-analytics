-- ==========================================================================
-- Portfolio 3: Financial Markets / Stock Analysis
-- File: stock_analyses.sql
-- Engine: SQLite 3.x
-- Table: stock_prices (columns: ticker, date, open, high, low, close,
--        volume, daily_return, market_cap)
-- ==========================================================================

-- Q01. SUMMARY PER TICKER
--   avg daily return, volatility,  Sharpe ratio approximation,
--   total cumulative return (product of gross returns - 1)
SELECT
    ticker,
    ROUND(AVG(daily_return) * 252, 6)                                  AS annualized_return,
    ROUND(AVG(daily_return), 8)                                         AS avg_daily_return,
    ROUND(SQRT(252) * std(daily_return), 6)                             AS annualized_volatility,
    ROUND(std(daily_return), 8)                                         AS daily_volatility,
    ROUND(AVG(daily_return) * 252 / NULLIF(SQRT(252) * std(daily_return), 0), 4) AS sharpe_approx,
    ROUND(EXP(SUM(LN(1 + daily_return))) - 1, 6)                       AS total_cumulative_return,
    COUNT(*)                                                             AS obs
FROM stock_prices
GROUP BY ticker
ORDER BY annualized_return DESC;

-- Q02. TOP PERFORMERS (annualized return)
SELECT
    ticker,
    ROUND(AVG(daily_return) * 252, 6)                                   AS ann_return,
    ROUND(SQRT(252) * std(daily_return), 6)                              AS ann_vol,
    ROUND(AVG(daily_return) * 252
          / NULLIF(SQRT(252) * std(daily_return), 0), 4)                AS sharpe,
    RANK() OVER (ORDER BY AVG(daily_return) * 252 DESC)                 AS performance_rank
FROM stock_prices
GROUP BY ticker
ORDER BY ann_return DESC
LIMIT 5;

-- Q03. CUMULATIVE RETURN TIME SERIES
--   window function with product via EXP(SUM(LN(...)) OVER ...)
SELECT
    ticker,
    date,
    close,
    ROUND(EXP(SUM(LN(1 + daily_return)) OVER (
        PARTITION BY ticker ORDER BY date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )) - 1, 6) AS cumulative_return
FROM stock_prices
WHERE ticker IN ('AAPL', 'NVDA', 'TSLA')
ORDER BY ticker, date;

-- Q04. VOLATILITY RANKING (stddev of daily returns, annualized)
SELECT
    ticker,
    ROUND(std(daily_return), 8)                                         AS daily_vol,
    ROUND(SQRT(252) * std(daily_return), 6)                             AS annualized_vol,
    RANK() OVER (ORDER BY std(daily_return) DESC)                       AS risk_rank
FROM stock_prices
GROUP BY ticker
ORDER BY daily_vol DESC;

-- Q05. MOVING AVERAGES - 50-day and 200-day (window functions)
SELECT
    ticker,
    date,
    close,
    ROUND(AVG(close) OVER (
        PARTITION BY ticker ORDER BY date
        ROWS BETWEEN 49 PRECEDING AND CURRENT ROW
    ), 4) AS ma50,
    ROUND(AVG(close) OVER (
        PARTITION BY ticker ORDER BY date
        ROWS BETWEEN 199 PRECEDING AND CURRENT ROW
    ), 4) AS ma200
FROM stock_prices
ORDER BY ticker, date;

-- Q06. GOLDEN CROSS / DEATH CROSS DETECTION
--   Golden cross : MA50 crosses above MA200
--   Death cross  : MA50 crosses below MA200
WITH ma AS (
    SELECT
        ticker, date, close,
        AVG(close) OVER (PARTITION BY ticker ORDER BY date
            ROWS BETWEEN 49 PRECEDING AND CURRENT ROW)  AS ma50,
        AVG(close) OVER (PARTITION BY ticker ORDER BY date
            ROWS BETWEEN 199 PRECEDING AND CURRENT ROW)  AS ma200
    FROM stock_prices
),
signals AS (
    SELECT
        ticker, date, close, ma50, ma200,
        LAG(ma50)  OVER (PARTITION BY ticker ORDER BY date) AS prev_ma50,
        LAG(ma200) OVER (PARTITION BY ticker ORDER BY date) AS prev_ma200,
        LAG(close) OVER (PARTITION BY ticker ORDER BY date) AS prev_close
    FROM ma
)
SELECT
    ticker,
    date,
    ROUND(close, 2)  AS price,
    ROUND(ma50, 2)   AS ma50,
    ROUND(ma200, 2)  AS ma200,
    CASE
        WHEN prev_ma50 IS NULL OR prev_ma200 IS NULL      THEN 'NO_DATA'
        WHEN prev_ma50 <= prev_ma200 AND ma50 >  ma200    THEN 'GOLDEN_CROSS'
        WHEN prev_ma50 >= prev_ma200 AND ma50 <  ma200    THEN 'DEATH_CROSS'
        ELSE 'NO_CROSS'
    END AS signal_type
FROM signals
WHERE ma200 IS NOT NULL
  AND prev_ma50 IS NOT NULL
  AND (
    (prev_ma50 <= prev_ma200 AND ma50 >  ma200)
    OR
    (prev_ma50 >= prev_ma200 AND ma50 <  ma200)
  )
ORDER BY ticker, date;

-- Q07. MONTHLY RETURNS HEATMAP DATA (CASE WHEN for months, pivot per year)
-- One row per ticker+year, 12 month-columns filled via conditional aggregation.
SELECT
    ticker,
    SUBSTR(date, 1, 4)                                                    AS yr,
    ROUND(SUM(CASE WHEN SUBSTR(date,6,2)='01' THEN daily_return END), 6)  AS jan,
    ROUND(SUM(CASE WHEN SUBSTR(date,6,2)='02' THEN daily_return END), 6)  AS feb,
    ROUND(SUM(CASE WHEN SUBSTR(date,6,2)='03' THEN daily_return END), 6)  AS mar,
    ROUND(SUM(CASE WHEN SUBSTR(date,6,2)='04' THEN daily_return END), 6)  AS apr,
    ROUND(SUM(CASE WHEN SUBSTR(date,6,2)='05' THEN daily_return END), 6)  AS may,
    ROUND(SUM(CASE WHEN SUBSTR(date,6,2)='06' THEN daily_return END), 6)  AS jun,
    ROUND(SUM(CASE WHEN SUBSTR(date,6,2)='07' THEN daily_return END), 6)  AS jul,
    ROUND(SUM(CASE WHEN SUBSTR(date,6,2)='08' THEN daily_return END), 6)  AS aug,
    ROUND(SUM(CASE WHEN SUBSTR(date,6,2)='09' THEN daily_return END), 6)  AS sep,
    ROUND(SUM(CASE WHEN SUBSTR(date,6,2)='10' THEN daily_return END), 6)  AS oct,
    ROUND(SUM(CASE WHEN SUBSTR(date,6,2)='11' THEN daily_return END), 6)  AS nov,
    ROUND(SUM(CASE WHEN SUBSTR(date,6,2)='12' THEN daily_return END), 6)  AS "dec"
FROM stock_prices
GROUP BY ticker, SUBSTR(date, 1, 4)
ORDER BY ticker, yr;

-- Q07b. Monthly returns pivot-style (one row per ticker+year-month)
SELECT
    ticker,
    SUBSTR(date, 1, 7)   AS ym,
    ROUND(SUM(daily_return), 6) AS monthly_return,
    COUNT(*)              AS trading_days
FROM stock_prices
GROUP BY ticker, SUBSTR(date, 1, 7)
ORDER BY ticker, ym;

-- Q08. VOLUME ANALYSIS  (avg volume + volume spikes > 2.5 x trailing 30d avg)
WITH vol_stats AS (
    SELECT
        ticker,
        ROUND(AVG(volume), 0)  AS avg_volume,
        MIN(volume)            AS min_volume,
        MAX(volume)            AS max_volume
    FROM stock_prices
    GROUP BY ticker
),
vol30 AS (
    SELECT
        ticker, date, volume,
        AVG(volume) OVER (PARTITION BY ticker ORDER BY date
            ROWS BETWEEN 29 PRECEDING AND 1 PRECEDING) AS trailing_30d_avg
    FROM stock_prices
)
SELECT
    v.ticker,
    v.date,
    v.volume,
    ROUND(vs.avg_volume, 0)                 AS overall_avg_volume,
    ROUND(v.trailing_30d_avg, 0)            AS trailing_30d_avg,
    ROUND(v.volume * 1.0
          / NULLIF(v.trailing_30d_avg, 0), 3) AS spike_ratio,
    CASE
        WHEN v.volume > 2.5 * v.trailing_30d_avg THEN 'SPIKE'
        ELSE 'NORMAL'
    END AS volume_flag
FROM vol30 v
JOIN vol_stats vs ON vs.ticker = v.ticker
WHERE v.trailing_30d_avg IS NOT NULL
  AND v.volume > 2.5 * v.trailing_30d_avg
ORDER BY v.ticker, spike_ratio DESC;

-- Q09. DRAWDOWN CALCULATION (running max -> percentage drop from peak)
WITH running_max AS (
    SELECT
        ticker, date, close,
        MAX(close) OVER (PARTITION BY ticker ORDER BY date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS peak_close
    FROM stock_prices
)
SELECT
    ticker,
    date,
    ROUND(close, 2)                                 AS close,
    ROUND(peak_close, 2)                            AS peak,
    ROUND((close - peak_close) / peak_close * 100, 4) AS drawdown_pct,
    RANK() OVER (PARTITION BY ticker ORDER BY
        (close - peak_close) / peak_close ASC)      AS worst_drawdown_rank
FROM running_max
ORDER BY ticker, drawdown_pct ASC;

-- Q10. MAX DRAWDOWN PER TICKER (summary)
WITH running_max AS (
    SELECT
        ticker, date, close,
        MAX(close) OVER (PARTITION BY ticker ORDER BY date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS peak_close
    FROM stock_prices
)
SELECT
    ticker,
    ROUND(MIN((close - peak_close) / peak_close) * 100, 4) AS max_drawdown_pct,
    COUNT(*) FILTER (WHERE close <  peak_close)            AS days_below_peak,
    COUNT(*)                                                AS total_obs
FROM running_max
GROUP BY ticker
ORDER BY max_drawdown_pct ASC;

-- Q11. CORRELATION MATRIX OF DAILY RETURNS (self-join)
SELECT
    a.ticker AS ticker_a,
    b.ticker AS ticker_b,
    ROUND(AVG(a.daily_return * b.daily_return), 8)
        AS cov_return,
    ROUND(
        (AVG(a.daily_return * b.daily_return)
         - AVG(a.daily_return) * AVG(b.daily_return))
        / (std(a.daily_return) * std(b.daily_return))
    , 6) AS correlation
FROM stock_prices a
JOIN stock_prices b
  ON a.date = b.date
 AND a.ticker <= b.ticker
GROUP BY a.ticker, b.ticker
ORDER BY ticker_a, ticker_b;

-- Q12. QUARTERLY PERFORMANCE (CTE + aggregation)
WITH quarterly AS (
    SELECT
        ticker,
        SUBSTR(date, 1, 4) AS yr,
        CASE
            WHEN SUBSTR(date, 6, 2) IN ('01','02','03') THEN 'Q1'
            WHEN SUBSTR(date, 6, 2) IN ('04','05','06') THEN 'Q2'
            WHEN SUBSTR(date, 6, 2) IN ('07','08','09') THEN 'Q3'
            ELSE 'Q4'
        END AS quarter,
        daily_return
    FROM stock_prices
)
SELECT
    ticker,
    yr,
    quarter,
    ROUND(SUM(daily_return) * 100, 4)      AS quarterly_return_pct,
    ROUND(AVG(daily_return) * 100, 4)       AS avg_daily_return_pct,
    ROUND(std(daily_return) * 100, 4)       AS daily_volatility_pct,
    COUNT(*)                                 AS trading_days
FROM quarterly
GROUP BY ticker, yr, quarter
ORDER BY ticker, yr, quarter;

-- Q13. BEST AND WORST SINGLE DAY PER TICKER
SELECT
    ticker,
    MAX(daily_return)                                                     AS best_day_return,
    (SELECT date FROM stock_prices s2
        WHERE s2.ticker = s1.ticker
        ORDER BY daily_return DESC LIMIT 1)                               AS best_day_date,
    MIN(daily_return)                                                     AS worst_day_return,
    (SELECT date FROM stock_prices s3
        WHERE s3.ticker = s1.ticker
        ORDER BY daily_return ASC LIMIT 1)                               AS worst_day_date,
    ROUND(MAX(daily_return) * 100, 4)  AS best_pct,
    ROUND(MIN(daily_return) * 100, 4)  AS worst_pct
FROM stock_prices s1
GROUP BY ticker
ORDER BY best_day_return DESC;

-- Q14. PORTFOLIO STATISTICS
--   equal-weight portfolio daily return -> annualized stats
WITH port AS (
    SELECT
        date,
        AVG(daily_return) AS port_daily_return
    FROM stock_prices
    GROUP BY date
)
SELECT
    COUNT(*)                                                                  AS days,
    ROUND(AVG(port_daily_return) * 252, 6)                                     AS ann_return,
    ROUND(SQRT(252) * std(port_daily_return), 6)                               AS ann_volatility,
    ROUND(AVG(port_daily_return) * 252
          / NULLIF(SQRT(252) * std(port_daily_return), 0), 4)                  AS sharpe,
    ROUND(EXP(SUM(LN(1 + port_daily_return))) - 1, 6)                          AS cum_return,
    MIN(port_daily_return)                                                     AS worst_day,
    MAX(port_daily_return)                                                     AS best_day
FROM port;

-- Q15. MARKET CAP SUMMARY (first / last / avg per ticker)
SELECT
    ticker,
    ROUND(market_cap / 1e9, 2)         AS market_cap_billions
FROM stock_prices
ORDER BY date DESC, ticker
LIMIT 10;

-- Q15b. Average and final market cap per ticker
SELECT
    ticker,
    ROUND(AVG(market_cap)  / 1e9, 2)  AS avg_market_cap_billions,
    ROUND(MAX(market_cap)  / 1e9, 2)  AS max_market_cap_billions,
    ROUND(MIN(market_cap)  / 1e9, 2)  AS min_market_cap_billions
FROM stock_prices
GROUP BY ticker
ORDER BY avg_market_cap_billions DESC;

-- Q16. YEARLY RETURN PER TICKER
SELECT
    ticker,
    SUBSTR(date, 1, 4) AS yr,
    ROUND(SUM(daily_return) * 100, 4) AS yearly_return_pct,
    ROUND(AVG(volume), 0)              AS avg_daily_volume
FROM stock_prices
GROUP BY ticker, SUBSTR(date, 1, 4)
ORDER BY ticker, yr;

-- Q17. RISK ADJUSTED RANK (Sortino-style downside deviation)
WITH downside AS (
    SELECT
        ticker,
        daily_return,
        CASE WHEN daily_return < 0 THEN daily_return END AS neg_ret
    FROM stock_prices
)
SELECT
    ticker,
    ROUND(AVG(daily_return) * 252, 6)                                  AS ann_return,
    ROUND(SQRT(252) * std(CASE WHEN daily_return < 0
                                THEN daily_return ELSE 0 END), 6)      AS downside_volatility,
    ROUND(AVG(daily_return) * 252
          / NULLIF(SQRT(252) * std(CASE WHEN daily_return < 0
                                THEN daily_return ELSE 0 END), 0), 4)   AS sortino_approx,
    RANK() OVER (ORDER BY
        AVG(daily_return) * 252
        / NULLIF(SQRT(252) * std(CASE WHEN daily_return < 0
                                THEN daily_return ELSE 0 END), 0) DESC) AS sortino_rank
FROM downside
GROUP BY ticker
ORDER BY sortino_approx DESC;

-- END OF SCRIPT
