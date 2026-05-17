# Research themes addressed

This pipeline is structured around four interlocking questions in
international macroeconomics and trade — the same questions that motivate the
kind of policy-oriented research a central-bank trade-and-quantitative-studies
team carries out on a recurring basis. Each theme maps to a concrete artifact
the pipeline produces.

## 1. Real vs nominal trade flows

> When U.S. imports rise, is the country buying more goods, or paying more for
> the same goods?

Headline trade releases mix two effects: changes in **volumes** and changes
in **trade prices**. The pipeline pulls both nominal (`Exports`, `Imports`)
and real (`RealExports`, `RealImports`) trade aggregates and constructs an
implicit deflator for each side. `RealNetExports` is the price-deflated trade
balance that enters the GDP identity.

→ Artifacts: `data/processed/cleaned_macro_trade_data.csv`
columns `RealExports`, `RealImports`, `RealNetExports`,
`ImportDeflator`, `ExportDeflator`, `TermsOfTrade`.

## 2. Exchange-rate pass-through to trade prices

> A 1-percent move in the dollar — how much shows up in U.S. import prices?

Stage 4b estimates a distributed-lag OLS regression of Δlog(import deflator)
on Δlog(dollar), with 0–4 quarter lags and a CPI control. The sum of the FX
coefficients is the cumulative pass-through. The mirror specification is
reported for the export deflator. The standard empirical finding (incomplete
pass-through for U.S. imports) is reproduced and reported with confidence
intervals so the coefficient is auditable.

→ Artifacts: `outputs/tables/passthrough_coefficients.csv`,
`outputs/figures/06_fx_vs_import_deflator.png`.

## 3. Net-exports forecasting under uncertainty

> What is the central forecast for U.S. real net exports over the next two
> years, and how wide is the uncertainty band?

Stage 4 fits `forecast::auto.arima` to the quarterly net-exports series and
reports an 8-quarter-ahead forecast with 80% and 95% prediction intervals.
This is the same workflow used to build a baseline path that richer
structural and judgmental models are compared against.

→ Artifacts: `outputs/figures/04_forecast_net_exports.png`,
`outputs/tables/forecast_results.csv` (target = `NetExports`).

## 4. Commodity price dynamics

> What is the unconditional ARIMA path for crude oil over the next two years?

The same forecasting framework is applied to crude oil (WTI) so the project
ships a *commodity* forecast alongside the macro and trade forecasts — and
so the panel can be extended to test joint dynamics between the dollar,
crude oil, and U.S. net exports without rewriting the forecasting layer.

→ Artifacts: `outputs/figures/07_forecast_oil_wti.png`,
`outputs/tables/forecast_results.csv` (target = `OilWTI`).

---

## How the themes compose

The four themes share the same data layer and helper functions, so any
question that combines them is one short script away:

| Question | Combines themes | Artifact path |
|---|---|---|
| Does an oil shock change pass-through? | 2 + 4 | extend `04b_pass_through.R` to add `dlog_oil` as a regressor |
| Are trade flows or trade prices driving the net-exports forecast? | 1 + 3 | overlay `RealNetExports_forecast` on `NetExports_forecast` |
| Is the dollar driving the trade balance through prices or quantities? | 1 + 2 | run pass-through on both deflators and on `RealImports` separately |

Each of those extensions is genuinely *one script* of work because the
quarterly panel, the deflator helpers, and the pass-through helpers are all
already in place.

## Limitations

- Univariate ARIMA forecasts ignore the macro covariates the pipeline
  collects (dollar, oil, rates). A multivariate VAR or local-projections
  approach would use them and is the natural next step.
- The pass-through regression treats the dollar as exogenous. In practice
  the dollar co-moves with the same shocks that move U.S. trade prices,
  which biases simple OLS toward zero. IV / monetary-policy-surprise
  identification or a structural model would address this.
- Mobility / tariff / micro trade data could add identification power but
  are out of scope for the public-FRED-only version of this pipeline.
