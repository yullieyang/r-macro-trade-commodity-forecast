# r-macro-trade-commodity-forecast

A reproducible R workflow for retrieving, cleaning, analyzing, and forecasting
U.S. macroeconomic, **trade-flow**, and commodity-price indicators — together
with an **exchange-rate pass-through** analysis on U.S. trade prices. The
project is structured as a production-style research-support pipeline: each
stage is a numbered script, shared logic lives in modular functions under
`R/`, and all artifacts (processed data, figures, model summaries) are
versioned to disk so downstream consumers and reviewers can audit every step.

## Why this project

Policy-oriented international-finance research teams routinely need to:

- Pull macroeconomic, **trade-flow**, and commodity-price series from
  authoritative sources on a recurring basis.
- Harmonize series that arrive at different frequencies (daily oil and dollar
  index, monthly CPI / unemployment / commodities, quarterly GDP and nominal
  + real trade aggregates).
- Build derived measures — year-over-year growth, net exports, terms of
  trade, **implicit import / export deflators**, oil-price changes — that
  feed briefings, forecasts, and internal dashboards.
- Estimate empirical regularities of central interest to the trade-and-
  quantitative-studies literature, e.g. the cumulative **pass-through** of
  the dollar to U.S. import and export prices.
- Produce short-horizon forecasts with documented uncertainty for variables
  such as **net exports**, **real GDP**, and **crude oil** prices.
- Ship the entire process as code: reproducible, parameterized, and reviewable
  via Git rather than buried in ad-hoc spreadsheets.

This repository demonstrates that workflow end-to-end using only public FRED
data, with the same project layout, naming conventions, and documentation
standards I would use on a production research codebase.

See [`docs/research_themes.md`](docs/research_themes.md) for the four
research themes the pipeline directly addresses (real-vs-nominal trade,
pass-through, net-exports forecasting, commodity dynamics).

## Data sources

All data are sourced from the Federal Reserve Bank of St. Louis FRED database
via the `fredr` package. The default series are:

| Series ID    | Description                                            | Frequency | Used for |
|--------------|--------------------------------------------------------|-----------|----------|
| `GDPC1`      | Real Gross Domestic Product (chained 2017 dollars)     | Quarterly | Macro, forecast |
| `UNRATE`     | Civilian Unemployment Rate                             | Monthly   | Macro |
| `FEDFUNDS`   | Effective Federal Funds Rate                           | Monthly   | Macro |
| `CPIAUCSL`   | Consumer Price Index for All Urban Consumers           | Monthly   | Pass-through control |
| `INDPRO`     | Industrial Production: Total Index                     | Monthly   | Macro |
| `EXPGS`      | Exports of Goods and Services (nominal)                | Quarterly | Trade, deflator |
| `IMPGS`      | Imports of Goods and Services (nominal)                | Quarterly | Trade, deflator |
| `EXPGSC1`    | Real Exports of Goods and Services                     | Quarterly | Trade, deflator |
| `IMPGSC1`    | Real Imports of Goods and Services                     | Quarterly | Trade, deflator |
| `DTWEXBGS`   | Trade-Weighted U.S. Dollar Index: Broad (Goods+Svcs)   | Daily     | Pass-through |
| `DCOILWTICO` | Crude Oil Prices: West Texas Intermediate (WTI)        | Daily     | Commodity, forecast |
| `DHHNGSP`    | Henry Hub Natural Gas Spot Price                       | Daily     | Commodity |
| `PCOPPUSDM`  | Global Price of Copper                                 | Monthly   | Commodity |

The series list lives in `scripts/01_get_data.R` and can be edited in one
place without touching the rest of the pipeline.

## Methodology

1. **Ingest** — `01_get_data.R` calls `get_fred_series()` once per series and
   writes a long-format raw snapshot to `data/raw/`.
2. **Clean & transform** — `02_clean_transform_data.R` aligns every series to
   a common quarterly grid (period-average aggregation), computes derived
   measures (nominal and real net exports, YoY / QoQ growth, log oil price,
   **implicit import / export deflators, terms of trade**), and writes
   `data/processed/cleaned_macro_trade_data.csv`.
3. **Explore** — `03_exploratory_analysis.R` produces descriptive summaries,
   a multi-panel time-series chart, a net-exports trend chart, and a
   correlation heatmap between oil, trade, and macro variables.
4. **Forecast** — `04_forecast_model.R` loops over a configurable target
   list (currently `NetExports`, `RealGDP`, **and `OilWTI`**), fits an ARIMA
   model auto-selected by `forecast::auto.arima` for each, generates an
   8-quarter forecast with 80% / 95% prediction intervals, and writes
   combined model-summary and forecast-results tables (one row per
   target × term) plus one figure per target.
5. **Pass-through (4b)** — `04b_pass_through.R` estimates a distributed-lag
   regression of Δlog(import / export deflator) on Δlog(broad dollar) with
   0–4 quarter lags and a CPI control, and reports the cumulative
   pass-through coefficient and a contemporaneous co-movement scatter.
6. **Generate outputs** — `05_generate_outputs.R` is the entry point that
   sources the full pipeline (1 → 4b) so a reviewer can reproduce every
   artifact with a single command.

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
│   ├── passthrough_utils.R      #  (new) pass-through regression helpers
│   └── io_utils.R
├── scripts/                     # Numbered pipeline stages
│   ├── 01_get_data.R
│   ├── 02_clean_transform_data.R
│   ├── 03_exploratory_analysis.R
│   ├── 04_forecast_model.R
│   ├── 04b_pass_through.R       #  (new) FX pass-through to trade prices
│   └── 05_generate_outputs.R
├── data/
│   ├── raw/                     # Untouched FRED snapshots
│   └── processed/               # Quarterly panel + derived measures
├── outputs/
│   ├── figures/                 # PNG charts
│   └── tables/                  # CSV summaries
└── docs/
    ├── methodology.md
    ├── data_dictionary.md
    └── research_themes.md       #  (new) explicit research-question framing
```

## How to run

### 1. Install R packages

```r
install.packages(c(
  "tidyverse", "lubridate", "fredr", "forecast",
  "ggplot2", "readr", "broom", "here", "scales"
))
```

`broom` is used by the pass-through stage to tidy `lm` coefficients into
the same row-per-term schema as the ARIMA outputs.

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

Data and tables:

- `data/processed/cleaned_macro_trade_data.csv` — analysis-ready quarterly
  panel with raw levels and derived measures.
- `outputs/tables/model_summary.csv` — tidy ARIMA coefficients (with
  standard errors and p-values) and fit diagnostics for every target,
  stacked with a `target` column.
- `outputs/tables/forecast_results.csv` — point forecasts and 80% / 95%
  intervals for the next 8 quarters, per target.
- `outputs/tables/descriptive_summary.csv` — per-series n / range / mean
  / sd reference.

Figures (rendered below from `outputs/figures/`):

### Macro, trade, and commodity overview

![Macro / trade / commodity overview](outputs/figures/01_macro_trade_overview.png)

### Net exports trend

![Net exports trend](outputs/figures/02_net_exports_trend.png)

### Co-movement of oil, trade, and macro variables

![Correlation heatmap](outputs/figures/03_correlation_heatmap.png)

### 8-quarter ARIMA forecast — net exports

`auto.arima` selected **ARIMA(0,1,0)** for net exports — i.e. a random
walk without drift. This is a defensible baseline (US net exports are
close to a random walk at quarterly frequency) and the chart shows the
flat point forecast with fanning prediction bands.

![Net exports forecast](outputs/figures/04_forecast_net_exports.png)

### 8-quarter ARIMA forecast — real GDP

`auto.arima` selected **ARIMA(0,1,1) with drift** for real GDP — an MA(1)
on first differences plus a positive drift term capturing trend growth.
This is a richer specification than the net-exports baseline and
illustrates the same pipeline handling structurally different targets.

![Real GDP forecast](outputs/figures/05_forecast_real_gdp.png)

### 8-quarter ARIMA forecast — crude oil (WTI)

A commodity-price target sits alongside the macro and trade targets, so the
panel covers the three categories called out in the project name. The same
`auto.arima` machinery is reused; the model selection, prediction intervals,
and output schema are all identical to the macro targets.

![Oil WTI forecast](outputs/figures/07_forecast_oil_wti.png)

### Exchange-rate pass-through to U.S. import prices

Stage 4b estimates the share of a quarterly move in the broad trade-weighted
dollar that is reflected in the implicit U.S. import deflator, with 0–4
quarter lags and a CPI control. The cumulative coefficient reported in
`outputs/tables/passthrough_coefficients.csv` is the central quantity in the
empirical trade-prices literature; the figure below shows the contemporaneous
slice of the regression.

![FX pass-through scatter](outputs/figures/06_fx_vs_import_deflator.png)

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

## Development & AI workflow

This pipeline was built with **[Claude Code](https://claude.com/claude-code)** as a pair-programming and review collaborator. Concretely, Claude Code was used to:

- Scaffold the modular `R/` helper layer and the numbered `scripts/` pipeline,
  then iteratively refactor as the design solidified.
- Co-author the methodology and data-dictionary documents in `docs/`.
- Review diffs for naming consistency, `here::here()` path discipline, and
  removal of hard-coded values before commit.
- Generate this README and the inline-figure section so the repo renders as a
  short technical brief on its GitHub landing page.

The intent mirrors what a production research-support workflow looks like:
human-authored economic and modeling decisions, with an LLM collaborator
handling boilerplate, style enforcement, and documentation. Prompt history
and key conversations can be reproduced from `CLAUDE.md` (added on request).

## Resume bullet

> Built a modular R pipeline to collect, maintain, and analyze
> macroeconomic, trade-flow, and commodity price indicators from FRED,
> including exports, imports, net exports, oil prices, GDP, unemployment,
> and interest rate data.
>
> Harmonized time series into a quarterly panel and produced ARIMA-based
> 8-quarter forecasts with documented assumptions to support review of
> macro-trade conditions and commodity price movements. Extended the panel
> with implicit import / export deflators and a distributed-lag estimate of
> the dollar's cumulative pass-through to U.S. trade prices.
