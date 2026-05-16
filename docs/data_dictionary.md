# Data dictionary

Columns in `data/processed/cleaned_macro_trade_data.csv` (wide quarterly
panel). Dates are quarter-start. All `*_yoy` and `*_qoq` columns are
decimal growth rates (0.05 = 5%).

## Level series (from FRED)

| Column                 | FRED ID      | Units                                    |
|------------------------|--------------|------------------------------------------|
| `date`                 | n/a          | Quarter-start date                       |
| `OilWTI`               | `DCOILWTICO` | USD per barrel, period average           |
| `Exports`              | `EXPGS`      | Billions of USD, SAAR                    |
| `Imports`              | `IMPGS`      | Billions of USD, SAAR                    |
| `RealGDP`              | `GDPC1`      | Billions of chained 2017 USD, SAAR       |
| `Unemployment`         | `UNRATE`     | Percent, seasonally adjusted             |
| `FedFunds`             | `FEDFUNDS`   | Percent, effective rate                  |
| `CPI`                  | `CPIAUCSL`   | Index (1982–84 = 100), SA                |
| `IndustrialProduction` | `INDPRO`     | Index (2017 = 100), SA                   |
| `USDIndex`             | `DTWEXBGS`   | Index (Jan 2006 = 100), broad goods+svcs |

## Derived measures

| Column                 | Definition                                       |
|------------------------|--------------------------------------------------|
| `NetExports`           | `Exports - Imports` (billions of USD, SAAR)      |
| `TradeBalanceRatio`    | `NetExports / (Exports + Imports)`               |
| `OilWTI_log`           | Natural log of `OilWTI`                          |
| `OilWTI_change`        | Quarterly change in `OilWTI` (USD/barrel)        |
| `<var>_yoy`            | `<var>_t / <var>_{t-4} - 1`                      |
| `<var>_qoq`            | `<var>_t / <var>_{t-1} - 1`                      |

## Long format

`data/processed/cleaned_macro_trade_long.csv` carries the same level
series in long form for plotting:

| Column      | Type   | Description                            |
|-------------|--------|----------------------------------------|
| `date`      | Date   | Quarter-start                          |
| `series_id` | char   | FRED identifier                        |
| `label`     | char   | Human-readable name used in plots      |
| `value`     | num    | Period-average level                   |
