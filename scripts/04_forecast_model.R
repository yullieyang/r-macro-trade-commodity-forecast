# scripts/04_forecast_model.R
# Stage 4: Fit a quarterly ARIMA forecast for U.S. real net exports and
# write the model summary + forecast results to disk.
#
# Outputs:
#   outputs/tables/model_summary.csv
#   outputs/tables/forecast_results.csv
#   outputs/figures/04_forecast_net_exports.png

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
FIG_FORECAST    <- proj_path("outputs", "figures", "04_forecast_net_exports.png")

# ---- 1. Configuration ----------------------------------------------------

TARGET_VAR       <- "NetExports"
FORECAST_HORIZON <- 8L            # quarters

# ---- 2. Load and prepare -------------------------------------------------

wide <- read_csv_safe(PROCESSED_WIDE)

if (!TARGET_VAR %in% names(wide)) {
  stop("Target variable '", TARGET_VAR,
       "' not found in processed panel.", call. = FALSE)
}

target_df <- wide |>
  dplyr::select(date, value = dplyr::all_of(TARGET_VAR)) |>
  dplyr::filter(!is.na(value))

target_ts <- as_quarterly_ts(target_df, freq = 4)

# ---- 3. Fit and forecast -------------------------------------------------

set.seed(2026)  # auto.arima itself is deterministic, but pin for safety.
fit <- fit_arima_forecast(target_ts, h = FORECAST_HORIZON)

message("Selected model: ", as.character(fit$model))

# ---- 4. Persist outputs --------------------------------------------------

save_model_summary(fit$model, fit$tidy_summary, TBL_MODEL)

forecast_tbl <- forecast_to_tibble(target_df, fit$forecast)
write_csv_safe(forecast_tbl, TBL_FORECAST)

p_fc <- create_forecast_plot(target_df, fit$forecast, var_name = TARGET_VAR)
save_figure(p_fc, FIG_FORECAST, width = 9, height = 5)

message("Forecast artifacts written:")
message("  - ", TBL_MODEL)
message("  - ", TBL_FORECAST)
message("  - ", FIG_FORECAST)
