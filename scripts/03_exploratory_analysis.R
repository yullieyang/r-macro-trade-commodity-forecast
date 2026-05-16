# scripts/03_exploratory_analysis.R
# Stage 3: Descriptive summaries and exploratory figures.
#
# Outputs:
#   outputs/tables/descriptive_summary.csv
#   outputs/figures/01_macro_trade_overview.png
#   outputs/figures/02_net_exports_trend.png
#   outputs/figures/03_correlation_heatmap.png

suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
})

source(here::here("R", "io_utils.R"))
source(here::here("R", "plot_utils.R"))

PROCESSED_WIDE <- proj_path("data", "processed", "cleaned_macro_trade_data.csv")
PROCESSED_LONG <- proj_path("data", "processed", "cleaned_macro_trade_long.csv")

FIG_OVERVIEW   <- proj_path("outputs", "figures", "01_macro_trade_overview.png")
FIG_NETEXPORTS <- proj_path("outputs", "figures", "02_net_exports_trend.png")
FIG_CORR       <- proj_path("outputs", "figures", "03_correlation_heatmap.png")
TBL_SUMMARY    <- proj_path("outputs", "tables",  "descriptive_summary.csv")

# ---- 1. Load --------------------------------------------------------------

wide <- read_csv_safe(PROCESSED_WIDE)
long <- read_csv_safe(PROCESSED_LONG)

# ---- 2. Descriptive summary table ---------------------------------------

descr <- long |>
  dplyr::group_by(label) |>
  dplyr::summarise(
    n_obs   = dplyr::n(),
    start   = min(date),
    end     = max(date),
    mean    = mean(value, na.rm = TRUE),
    sd      = sd(value,   na.rm = TRUE),
    min     = min(value,  na.rm = TRUE),
    median  = median(value, na.rm = TRUE),
    max     = max(value,  na.rm = TRUE),
    .groups = "drop"
  )

write_csv_safe(descr, TBL_SUMMARY)

# ---- 3. Figure 1: macro/trade/commodity overview ------------------------

overview_vars <- c(
  "OilWTI", "RealGDP", "Exports", "Imports",
  "Unemployment", "FedFunds", "CPI", "IndustrialProduction"
)

p_overview <- create_overview_plot(long, overview_vars)
save_figure(p_overview, FIG_OVERVIEW, width = 9, height = 7)

# ---- 4. Figure 2: net exports trend --------------------------------------

p_netex <- create_net_exports_plot(wide)
save_figure(p_netex, FIG_NETEXPORTS, width = 9, height = 4.5)

# ---- 5. Figure 3: correlation heatmap ------------------------------------

corr_vars <- c(
  "OilWTI", "RealGDP", "Exports", "Imports", "NetExports",
  "Unemployment", "FedFunds", "CPI", "IndustrialProduction", "USDIndex"
)
# Restrict to columns actually present (USDIndex etc. could be sparse).
corr_vars <- intersect(corr_vars, names(wide))

p_corr <- create_correlation_plot(wide, corr_vars)
save_figure(p_corr, FIG_CORR, width = 8, height = 7)

message("Exploratory artifacts written to outputs/.")
