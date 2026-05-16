# scripts/02_clean_transform_data.R
# Stage 2: Align frequencies, build a wide quarterly panel, and compute
# derived measures (net exports, YoY/QoQ growth, oil-price changes).
#
# Output: data/processed/cleaned_macro_trade_data.csv

suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(tidyr)
  library(readr)
})

source(here::here("R", "io_utils.R"))
source(here::here("R", "transform_utils.R"))

RAW_PATH       <- proj_path("data", "raw",       "fred_raw_long.csv")
PROCESSED_PATH <- proj_path("data", "processed", "cleaned_macro_trade_data.csv")
PROCESSED_LONG <- proj_path("data", "processed", "cleaned_macro_trade_long.csv")

# ---- 1. Load -------------------------------------------------------------

raw_long <- read_csv_safe(RAW_PATH)

stopifnot(all(c("date", "series_id", "label", "value") %in% names(raw_long)))

# ---- 2. Per-series cleaning + quarterly aggregation ----------------------

quarterly_long <- raw_long |>
  dplyr::group_by(series_id, label) |>
  dplyr::group_modify(~ to_quarterly(.x)) |>
  dplyr::ungroup() |>
  dplyr::select(date, series_id, label, value)

# ---- 3. Pivot to wide and add derived measures ---------------------------

quarterly_wide <- quarterly_long |>
  pivot_quarterly_wide(name_from = "label")

# Growth rates on all numeric (level) columns.
quarterly_wide <- calculate_growth_rates(quarterly_wide)

# Trade derived measures (NetExports, TradeBalanceRatio).
quarterly_wide <- add_trade_derived(quarterly_wide)

# Oil derived measures (log price, quarterly change).
quarterly_wide <- add_oil_derived(quarterly_wide, oil_col = "OilWTI")

# Drop the most recent quarter if any headline level series is still NA
# (FRED sometimes lags GDP/trade by a quarter). This keeps the analysis
# panel balanced without ad-hoc per-series filtering downstream.
balance_cols <- c("RealGDP", "Exports", "Imports", "OilWTI")
quarterly_wide <- quarterly_wide |>
  dplyr::arrange(date) |>
  dplyr::filter(
    !dplyr::if_any(dplyr::all_of(balance_cols), is.na) |
      date < max(date)
  )

# ---- 4. Persist ----------------------------------------------------------

write_csv_safe(quarterly_wide, PROCESSED_PATH)
write_csv_safe(quarterly_long, PROCESSED_LONG)

message(sprintf(
  "Wrote cleaned quarterly panel: %s rows x %s cols -> %s",
  nrow(quarterly_wide), ncol(quarterly_wide), PROCESSED_PATH
))
