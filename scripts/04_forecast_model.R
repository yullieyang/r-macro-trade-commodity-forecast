# scripts/04_forecast_model.R
# Stage 4: Fit quarterly ARIMA forecasts for one or more target series.
#
# A single config (TARGETS) drives the loop, so adding/removing forecast
# variables is a one-line change. Model summaries and forecast results
# from all targets are stacked into combined CSVs with a `target` column,
# which keeps the output schema stable and BI-friendly. One PNG is
# produced per target.
#
# Outputs:
#   outputs/tables/model_summary.csv      (combined across targets)
#   outputs/tables/forecast_results.csv   (combined across targets)
#   outputs/figures/04_forecast_<target>.png

suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(readr)
  library(tibble)
  library(forecast)
})

source(here::here("R", "io_utils.R"))
source(here::here("R", "model_utils.R"))
source(here::here("R", "plot_utils.R"))

PROCESSED_WIDE  <- proj_path("data", "processed", "cleaned_macro_trade_data.csv")
TBL_MODEL       <- proj_path("outputs", "tables",  "model_summary.csv")
TBL_FORECAST    <- proj_path("outputs", "tables",  "forecast_results.csv")
FIG_DIR         <- proj_path("outputs", "figures")

# ---- 1. Configuration ----------------------------------------------------

# Each row: column to forecast + display name + output figure file name.
# Net exports is a near-random-walk and provides an honest baseline;
# real GDP exercises a richer trend+seasonal structure.
TARGETS <- tibble::tribble(
  ~column,       ~display_name,                  ~fig_file,
  "NetExports",  "Net exports (USD B)",          "04_forecast_net_exports.png",
  "RealGDP",     "Real GDP (USD B)",             "05_forecast_real_gdp.png",
  "OilWTI",      "Crude oil, WTI (USD/barrel)",  "07_forecast_oil_wti.png"
)

FORECAST_HORIZON <- 8L  # quarters

# ---- 2. Load -------------------------------------------------------------

wide <- read_csv_safe(PROCESSED_WIDE)

# ---- 3. Per-target fit + persist ----------------------------------------

set.seed(2026)

all_models    <- list()
all_forecasts <- list()

for (i in seq_len(nrow(TARGETS))) {

  target_col   <- TARGETS$column[i]
  display_name <- TARGETS$display_name[i]
  fig_path     <- file.path(FIG_DIR, TARGETS$fig_file[i])

  if (!target_col %in% names(wide)) {
    warning("Skipping missing target column: ", target_col)
    next
  }

  message("Fitting ARIMA for ", target_col, " ...")

  target_df <- wide |>
    dplyr::select(date, value = dplyr::all_of(target_col)) |>
    dplyr::filter(!is.na(value))

  target_ts <- as_quarterly_ts(target_df, freq = 4)
  fit       <- fit_arima_forecast(target_ts, h = FORECAST_HORIZON)

  message("  Selected: ", as.character(fit$model))

  # --- Tidy model summary with target column ---
  diagnostics <- tibble::tibble(
    term      = c("aic", "bic", "sigma_sq", "log_likelihood", "n_obs"),
    estimate  = c(stats::AIC(fit$model),
                  stats::BIC(fit$model),
                  fit$model$sigma2,
                  as.numeric(stats::logLik(fit$model)),
                  as.numeric(fit$model$nobs)),
    std_error = NA_real_,
    z         = NA_real_,
    p_value   = NA_real_
  )
  model_rows <- dplyr::bind_rows(fit$tidy_summary, diagnostics) |>
    dplyr::mutate(target = target_col, model = as.character(fit$model),
                  .before = 1L)

  # --- Tidy forecast with target column ---
  fc_rows <- forecast_to_tibble(target_df, fit$forecast) |>
    dplyr::mutate(target = target_col, .before = 1L)

  all_models[[length(all_models) + 1L]]       <- model_rows
  all_forecasts[[length(all_forecasts) + 1L]] <- fc_rows

  # --- Figure per target ---
  p_fc <- create_forecast_plot(target_df, fit$forecast, var_name = display_name)
  save_figure(p_fc, fig_path, width = 9, height = 5)
}

# ---- 4. Write combined tables -------------------------------------------

write_csv_safe(dplyr::bind_rows(all_models),    TBL_MODEL)
write_csv_safe(dplyr::bind_rows(all_forecasts), TBL_FORECAST)

message("\nForecast artifacts written:")
message("  - ", TBL_MODEL)
message("  - ", TBL_FORECAST)
message("  - ", FIG_DIR, "/04_forecast_*.png and 05_forecast_*.png")
