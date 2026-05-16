# r-macro-trade-commodity-forecast

A reproducible R workflow for retrieving, cleaning, analyzing, and forecasting
U.S. macroeconomic, trade, and commodity indicators. The project is structured
as a production-style research-support pipeline: each stage is a numbered
script, shared logic lives in modular functions under `R/`, and all artifacts
(processed data, figures, model summaries) are versioned to disk so downstream
consumers and reviewers can audit every step.

## Why this project

Policy-oriented research teams routinely need to:

- Pull macroeconomic, trade, and commodity series from authoritative sources
  on a recurring basis.
- Harmonize series that arrive at different frequencies (daily oil prices,
  monthly CPI / unemployment, quarterly GDP / trade flows).
- Build derived measures — year-over-year growth, net exports, oil-price
  changes — that feed briefings, forecasts, and internal dashboards.
- Produce short-horizon forecasts with documented uncertainty for variables
  such as net exports or crude oil prices.
- Ship the entire process as code: reproducible, parameterized, and reviewable
  via Git rather than buried in ad-hoc spreadsheets.

This repository demonstrates that workflow end-to-end using only public FRED
data, with the same project layout, naming conventions, and documentation
standards I would use on a production research codebase.

## Data sources

All data are sourced from the Federal Reserve Bank of St. Louis FRED database
via the `fredr` package. The default series are:

| Series ID    | Description                                          | Frequency |
|--------------|------------------------------------------------------|-----------|
| `DCOILWTICO` | Crude Oil Prices: West Texas Intermediate (WTI)      | Daily     |
| `IMPGS`      | Imports of Goods and Services                        | Quarterly |
| `EXPGS`      | Exports of Goods and Services                        | Quarterly |
| `GDPC1`      | Real Gross Domestic Product (chained 2017 dollars)   | Quarterly |
| `UNRATE`     | Civilian Unemployment Rate                           | Monthly   |
| `FEDFUNDS`   | Effective Federal Funds Rate                         | Monthly   |
| `CPIAUCSL`   | Consumer Price Index for All Urban Consumers         | Monthly   |
| `INDPRO`     | Industrial Production: Total Index                   | Monthly   |
| `DTWEXBGS`   | Trade-Weighted U.S. Dollar Index: Broad (Goods+Svcs) | Daily     |

The series list lives in `scripts/01_get_data.R` and can be edited in one
place without touching the rest of the pipeline.

## Methodology

1. **Ingest** — `01_get_data.R` calls `get_fred_series()` once per series and
   writes a long-format raw snapshot to `data/raw/`.
2. **Clean & transform** — `02_clean_transform_data.R` aligns every series to
   a common quarterly grid (period-average aggregation), computes derived
   measures (net exports, YoY growth, QoQ change, log oil price), and writes
   `data/processed/cleaned_macro_trade_data.csv`.
3. **Explore** — `03_exploratory_analysis.R` produces descriptive summaries,
   a multi-panel time-series chart, a net-exports trend chart, and a
   correlation heatmap between oil, trade, and macro variables.
4. **Forecast** — `04_forecast_model.R` fits an ARIMA model (auto-selected by
   `forecast::auto.arima`) to real net exports, generates an 8-quarter
   forecast with 80% / 95% prediction intervals, and saves a tidy model
   summary.
5. **Generate outputs** — `05_generate_outputs.R` is the entry point that
   sources the full pipeline so a reviewer can reproduce every artifact with
   a single command.

## Folder structure

```
r-macro-trade-commodity-forecast/
├── README.md
├── .Renviron.example            # Template for FRED_API_KEY
├── .gitignore
├── R/                           # Reusable helper functions
│   ├── data_utils.R
│   ├── transform_utils.R
│   ├── plot_utils.R
│   ├── model_utils.R
│   └── io_utils.R
├── scripts/                     # Numbered pipeline stages
│   ├── 01_get_data.R
│   ├── 02_clean_transform_data.R
│   ├── 03_exploratory_analysis.R
│   ├── 04_forecast_model.R
│   └── 05_generate_outputs.R
├── data/
│   ├── raw/                     # Untouched FRED snapshots
│   └── processed/               # Quarterly panel + derived measures
├── outputs/
│   ├── figures/                 # PNG charts
│   └── tables/                  # CSV summaries
└── docs/
    ├── methodology.md
    └── data_dictionary.md
```

## How to run

### 1. Install R packages

```r
install.packages(c(
  "tidyverse", "lubridate", "fredr", "forecast",
  "ggplot2", "readr", "broom", "here", "scales"
))
```

### 2. Add a FRED API key

Request a free key at <https://fred.stlouisfed.org/docs/api/api_key.html>,
then copy the template and set the value:

```bash
cp .Renviron.example .Renviron
# Edit .Renviron and set FRED_API_KEY=your_key_here
```

`.Renviron` is loaded automatically by R at startup and is git-ignored.

### 3. Run the pipeline

From the project root (an RStudio project or a plain R session):

```r
source(here::here("scripts", "05_generate_outputs.R"))
```

This script sources stages 01–04 in order and then writes the final figures
and tables. Each stage can also be run independently for debugging.

## Key outputs

- `data/processed/cleaned_macro_trade_data.csv` — analysis-ready quarterly
  panel with raw levels and derived measures.
- `outputs/tables/model_summary.csv` — tidy ARIMA coefficients with standard
  errors and p-values.
- `outputs/tables/forecast_results.csv` — point forecasts and 80% / 95%
  intervals for the next 8 quarters.
- `outputs/figures/01_macro_trade_overview.png` — multi-panel chart of key
  indicators.
- `outputs/figures/02_net_exports_trend.png` — net exports with recession
  context.
- `outputs/figures/03_correlation_heatmap.png` — correlation matrix of
  oil, trade, and macro variables.
- `outputs/figures/04_forecast_net_exports.png` — net-exports forecast with
  shaded prediction intervals.

## Limitations

- ARIMA on a single endogenous series is a baseline; production trade
  forecasts typically combine multivariate (VAR, BVAR, state-space) models
  with judgmental adjustment.
- Quarterly aggregation discards intra-quarter variation in oil and FX
  series; for some questions a mixed-frequency (MIDAS) approach would be
  more appropriate.
- The pipeline assumes FRED series IDs and definitions are stable; if a
  series is revised or deprecated, `scripts/01_get_data.R` is the single
  place to update.
- The forecast is unconditional and ignores structural breaks (e.g. COVID
  shock); for policy use, breakpoint diagnostics and scenario conditioning
  would be added.

## Future improvements

- Replace the single-equation ARIMA with a small VAR over oil, trade, and
  GDP, with impulse-response diagnostics.
- Add a `renv.lock` for fully reproducible package versions.
- Wire the pipeline into a GitHub Actions workflow that refreshes data on a
  monthly cron and publishes the figures as build artifacts.
- Add an R Markdown / Quarto briefing template that renders the figures and
  tables into a one-page memo.
- Add unit tests for the transform helpers (`testthat`) and lint with
  `lintr` / `styler` in CI.

## Resume bullet

> Built **r-macro-trade-commodity-forecast**, a modular R pipeline that
> ingests U.S. macro, trade, and commodity series from FRED, harmonizes them
> to a quarterly panel, computes derived measures (net exports, YoY/QoQ
> growth), and produces an 8-quarter ARIMA forecast with prediction
> intervals — packaged with reusable functions, `here::here()` paths,
> environment-variable API credentials, and reproducible figure/table
> outputs suitable for policy-oriented research support.
