# scripts/01_get_data.R
# Stage 1: Retrieve raw FRED series and write a long-format snapshot.
#
# Run from the project root:
#   source(here::here("scripts", "01_get_data.R"))
#
# Requires FRED_API_KEY in the environment. See README.md.

suppressPackageStartupMessages({
  library(here)
  library(tibble)
  library(dplyr)
  library(readr)
})

source(here::here("R", "io_utils.R"))
source(here::here("R", "data_utils.R"))

# ---- 1. Configuration ------------------------------------------------------

# Earliest observation requested from FRED. 1990 keeps the panel long enough
# to capture multiple business cycles while remaining well within the range
# of all series listed below.
START_DATE <- as.Date("1990-01-01")

# Series catalog. Editing this single object is the only change needed to
# swap in/out indicators across the entire pipeline.
SERIES_SPEC <- tibble::tribble(
  ~series_id,    ~label,
  # --- Macro headline ---
  "GDPC1",       "RealGDP",
  "UNRATE",      "Unemployment",
  "FEDFUNDS",    "FedFunds",
  "CPIAUCSL",    "CPI",
  "INDPRO",      "IndustrialProduction",
  # --- Trade flows (nominal and real) ---
  # Real volumes let us separate price effects from quantity effects in trade,
  # which is the central distinction in international-trade research on
  # exchange-rate pass-through and trade-flow elasticities.
  "EXPGS",       "Exports",
  "IMPGS",       "Imports",
  "EXPGSC1",     "RealExports",
  "IMPGSC1",     "RealImports",
  # --- Dollar (effective exchange rate, broad index) ---
  "DTWEXBGS",    "USDIndex",
  # --- Commodity prices ---
  "DCOILWTICO",  "OilWTI",
  "DHHNGSP",     "NatGasHH",
  "PCOPPUSDM",   "CopperGlobal"
)

RAW_PATH <- proj_path("data", "raw", "fred_raw_long.csv")

# ---- 2. Pull -------------------------------------------------------------

require_fred_key()

message("Pulling ", nrow(SERIES_SPEC), " FRED series since ", START_DATE, " ...")
raw_long <- get_fred_panel(SERIES_SPEC, start_date = START_DATE)

# ---- 3. Persist ----------------------------------------------------------

write_raw_snapshot(raw_long, RAW_PATH)

message(sprintf(
  "Wrote %s rows across %s series to %s",
  format(nrow(raw_long), big.mark = ","),
  dplyr::n_distinct(raw_long$series_id),
  RAW_PATH
))
