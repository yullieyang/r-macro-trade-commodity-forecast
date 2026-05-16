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

| Measure                 | Formula                                       |
|-------------------------|-----------------------------------------------|
| `NetExports`            | `Exports - Imports`                           |
| `TradeBalanceRatio`     | `NetExports / (Exports + Imports)`            |
| `<var>_yoy`             | `value_t / value_{t-4} - 1`                   |
| `<var>_qoq`             | `value_t / value_{t-1} - 1`                   |
| `OilWTI_log`            | `log(OilWTI)`                                 |
| `OilWTI_change`         | `OilWTI_t - OilWTI_{t-1}`                     |

`TradeBalanceRatio` is reported because the headline `NetExports` level is
sensitive to overall trade volume, while the ratio is more comparable across
decades of nominal-trade growth.

## 4. Forecasting model

Stage 4 fits `forecast::auto.arima()` to quarterly real net exports with:

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

## 5. Reproducibility guardrails

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

## 6. AI/LLM tooling — responsible use note

LLM assistants were used during development for boilerplate scaffolding,
docstring drafting, and rubber-duck code review. All generated code was
read, edited, and verified by a human before commit. No model was given a
FRED API key or any other credential, and no series data was uploaded to an
external service. This mirrors the responsible-AI-use posture appropriate
for policy-adjacent research support.
