# Methodology

This document explains the analytical choices made in the pipeline. The
README covers *how to run it*; this file covers *why each step looks the way
it does*.

## 1. Source selection

All series are sourced from FRED via the `fredr` API. FRED is chosen because:

- Series identifiers are stable and well-documented, which is critical for
  production reproducibility.
- The same vendor publishes both macro (GDP, unemployment, CPI, fed funds)
  and trade/commodity (oil, exports, imports, dollar index) series, so the
  whole panel comes from a single authoritative source.
- The API is rate-limited but free, and the `fredr` package handles
  pagination and retries.

## 2. Frequency alignment

The pipeline standardizes on **quarterly period averages**:

- Daily series (`DCOILWTICO`, `DTWEXBGS`) are averaged within each calendar
  quarter.
- Monthly series (`UNRATE`, `FEDFUNDS`, `CPIAUCSL`, `INDPRO`) are averaged
  within each calendar quarter.
- Quarterly series (`GDPC1`, `EXPGS`, `IMPGS`) pass through with their date
  stamp normalized to the first day of the quarter.

Period averaging — versus period-end snapshots — is the standard choice for
macro analysis because it dampens noise and matches the convention used in
the National Income and Product Accounts (NIPA) for flow variables.

Trade-off: this throws away intra-quarter dynamics. For applications where
within-quarter timing matters (e.g. event studies around oil shocks), a
mixed-frequency approach (MIDAS, weekly state-space) would be preferable.

## 3. Derived measures

| Measure                 | Formula                                                |
|-------------------------|--------------------------------------------------------|
| `NetExports`            | `Exports - Imports` (nominal)                          |
| `RealNetExports`        | `RealExports - RealImports`                            |
| `TradeBalanceRatio`     | `NetExports / (Exports + Imports)`                     |
| `ImportDeflator`        | `(Imports / RealImports) * 100`  *(implicit price)*    |
| `ExportDeflator`        | `(Exports / RealExports) * 100`  *(implicit price)*    |
| `TermsOfTrade`          | `ExportDeflator / ImportDeflator`                      |
| `<var>_yoy`             | `value_t / value_{t-4} - 1`                            |
| `<var>_qoq`             | `value_t / value_{t-1} - 1`                            |
| `OilWTI_log`            | `log(OilWTI)`                                          |
| `OilWTI_change`         | `OilWTI_t - OilWTI_{t-1}`                              |

The implicit `ImportDeflator` and `ExportDeflator` are constructed by dividing
the nominal trade level by the corresponding chained-real level — recovering
a Paasche-style price index without depending on a separately published BLS
trade-price series. These deflators are the price object that exchange-rate
changes pass through to, and they drive the pass-through analysis in §5.

`TradeBalanceRatio` is reported because the headline `NetExports` level is
sensitive to overall trade volume, while the ratio is more comparable across
decades of nominal-trade growth.

## 4. Forecasting model

Stage 4 fits `forecast::auto.arima()` to a configurable list of targets —
currently quarterly **net exports**, **real GDP**, and **crude oil (WTI)** —
with:

- `seasonal = TRUE` (so a seasonal AR/MA structure may be selected).
- `stepwise = FALSE` and `approximation = FALSE` to search the full model
  space rather than the fast heuristic — slower but more defensible for a
  one-shot batch run.
- An 8-quarter horizon (two years), reported at 80% and 95% prediction
  intervals.

ARIMA is intentionally chosen as a **baseline**: it has no exogenous
regressors and makes no structural assumptions, so it serves as a sanity
check against which richer models (VAR, BVAR, factor-augmented regressions)
would be benchmarked in a production setting.

## 5. Exchange-rate pass-through to trade prices

Stage 4b estimates a distributed-lag regression of log-changes in U.S.
implicit trade deflators on log-changes in the broad trade-weighted dollar:

> Δlog(P_M)_t  =  α  +  Σ_{k=0..K} β_k · Δlog(USD)_{t-k}  +  γ · Δlog(CPI)_t  +  ε_t

The sum **Σ β_k** is the *cumulative pass-through* — the share of a 1-percent
dollar move that is reflected in U.S. import prices after K quarters. The
empirical international-trade literature consistently finds short-run
pass-through far below one for U.S. imports, with the bulk of dollar
fluctuations absorbed by exporter mark-ups (incomplete pass-through). The
script writes the full coefficient table to
`outputs/tables/passthrough_coefficients.csv` and a scatter of contemporaneous
co-movement to `outputs/figures/06_fx_vs_import_deflator.png`. An equivalent
fit is reported for the U.S. export deflator.

This stage is intentionally simple — a single-equation OLS with classical
(non-robust) standard errors and 95% confidence intervals from
`broom::tidy(conf.int = TRUE)` — to keep the result inspectable on the
README. Heteroscedasticity-consistent (HC) standard errors via
`sandwich::vcovHC()` are a noted next step. A richer treatment would also
use IV (instrumenting the dollar with a basket-shift or monetary-policy
surprise), a state-space pass-through model with time-varying coefficients,
or a structural model with strategic complementarities in price-setting;
those are noted in `Future improvements` on the README.

## 6. Reproducibility guardrails

- All file paths go through `here::here()`; no `setwd()` calls, no absolute
  paths in source.
- The FRED API key is read from an environment variable populated via
  `.Renviron`; the file itself is git-ignored.
- Each script can run standalone, and `05_generate_outputs.R` orchestrates
  the full pipeline so a reviewer can reproduce every artifact with a
  single command.
- Random seed is pinned in `04_forecast_model.R` even though `auto.arima`
  is deterministic, to insulate future additions (e.g. bootstrapped
  intervals) from non-determinism.

## 7. AI/LLM tooling — responsible use note

LLM assistants were used during development for boilerplate scaffolding,
docstring drafting, and rubber-duck code review. All generated code was
read, edited, and verified by a human before commit. No model was given a
FRED API key or any other credential, and no series data was uploaded to an
external service. This mirrors the responsible-AI-use posture appropriate
for policy-adjacent research support.
