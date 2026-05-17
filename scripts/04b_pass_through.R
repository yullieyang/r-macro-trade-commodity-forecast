# scripts/04b_pass_through.R
# Stage 4b: Exchange-rate pass-through analysis for U.S. trade prices.
#
# Estimates how much of a quarterly move in the broad trade-weighted dollar
# is reflected in the implicit U.S. import and export deflators, allowing for
# distributed-lag effects up to four quarters. The cumulative-passthrough
# statistic is the central quantity of interest in the international-trade
# literature on trade prices and exchange-rate volatility.
#
# Outputs:
#   outputs/tables/passthrough_coefficients.csv  (one row per regressor x target)
#   outputs/figures/06_fx_vs_import_deflator.png (scatter of contemporaneous
#                                                 log-changes with fit)
#
# Run from project root:
#   source(here::here("scripts", "04b_pass_through.R"))

suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(readr)
  library(ggplot2)
})

source(here::here("R", "io_utils.R"))
source(here::here("R", "passthrough_utils.R"))

PROCESSED_WIDE <- proj_path("data", "processed", "cleaned_macro_trade_data.csv")
TBL_PASSTHRU   <- proj_path("outputs", "tables",  "passthrough_coefficients.csv")
FIG_PASSTHRU   <- proj_path("outputs", "figures", "06_fx_vs_import_deflator.png")

# ---- 1. Load -------------------------------------------------------------

wide <- read_csv_safe(PROCESSED_WIDE)

# Guard: if the deflator columns are missing we have nothing to estimate.
required <- c("ImportDeflator", "ExportDeflator", "USDIndex", "CPI")
missing  <- setdiff(required, names(wide))
if (length(missing)) {
  warning("Skipping pass-through stage; required columns missing: ",
          paste(missing, collapse = ", "))
  quit(save = "no", status = 0)
}

# ---- 2. Estimate ---------------------------------------------------------

MAX_LAG <- 4L

import_panel <- prep_passthrough_panel(
  wide, price_col = "ImportDeflator", fx_col = "USDIndex",
  control_cols = c("CPI"), max_lag = MAX_LAG
)
export_panel <- prep_passthrough_panel(
  wide, price_col = "ExportDeflator", fx_col = "USDIndex",
  control_cols = c("CPI"), max_lag = MAX_LAG
)

import_fit <- fit_passthrough_lm(import_panel, max_lag = MAX_LAG)
export_fit <- fit_passthrough_lm(export_panel, max_lag = MAX_LAG)

message(sprintf(
  "Cumulative pass-through (0..%dQ): imports = %+.3f  |  exports = %+.3f",
  MAX_LAG,
  import_fit$cumulative_passthrough,
  export_fit$cumulative_passthrough
))

# ---- 3. Persist ----------------------------------------------------------

combined <- dplyr::bind_rows(
  tidy_passthrough(import_fit, target_label = "ImportDeflator"),
  tidy_passthrough(export_fit, target_label = "ExportDeflator")
)
write_csv_safe(combined, TBL_PASSTHRU)
message("  Coefficients -> ", TBL_PASSTHRU)

# ---- 4. Figure: contemporaneous co-movement (imports) --------------------

p <- ggplot(import_panel, aes(x = dlog_fx, y = dlog_price)) +
  geom_point(alpha = 0.55, color = "#1f3a93") +
  geom_smooth(method = "lm", formula = y ~ x,
              se = TRUE, color = "#c0392b", fill = "#c0392b22") +
  geom_hline(yintercept = 0, color = "grey60", linetype = "dashed") +
  geom_vline(xintercept = 0, color = "grey60", linetype = "dashed") +
  labs(
    title    = "Exchange-rate pass-through, contemporaneous",
    subtitle = sprintf(
      "Cumulative pass-through (0..%dQ) to U.S. import deflator: %+.2f",
      MAX_LAG, import_fit$cumulative_passthrough
    ),
    x = expression(Delta * log * "(broad USD index)"),
    y = expression(Delta * log * "(implicit U.S. import deflator)"),
    caption = "Source: FRED. Quarterly, post-1990. lm fit shown on the contemporaneous slice; cumulative coefficient sums the distributed-lag regression."
  ) +
  theme_minimal(base_size = 11)

ggsave(FIG_PASSTHRU, p, width = 9, height = 5.2, dpi = 200)
message("  Figure       -> ", FIG_PASSTHRU)
