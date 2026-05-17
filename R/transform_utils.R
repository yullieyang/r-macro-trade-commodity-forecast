# R/transform_utils.R
# Frequency alignment and derived-measure helpers.
#
# The pipeline standardizes on a quarterly calendar (period end = quarter
# end). Higher-frequency series are aggregated by period average; lower-
# frequency series (already quarterly) pass through unchanged.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(lubridate)
})

#' Clip leading/trailing NA observations and de-duplicate by date.
#'
#' @param df Tibble with `date` and `value` columns.
clean_time_series <- function(df) {
  df |>
    dplyr::filter(!is.na(value)) |>
    dplyr::arrange(date) |>
    dplyr::distinct(date, .keep_all = TRUE)
}

#' Aggregate a (possibly high-frequency) series to quarterly period averages.
#'
#' Each observation is mapped to the first day of its quarter, then averaged
#' within the quarter. For series that are already quarterly this is a
#' no-op except for normalizing the date stamp to quarter start.
#'
#' @param df Tibble with `date` and `value` columns.
to_quarterly <- function(df) {
  df |>
    clean_time_series() |>
    dplyr::mutate(quarter = lubridate::floor_date(date, unit = "quarter")) |>
    dplyr::group_by(quarter) |>
    dplyr::summarise(value = mean(value, na.rm = TRUE), .groups = "drop") |>
    dplyr::rename(date = quarter)
}

#' Pivot a long quarterly panel to wide form keyed on a chosen column.
#'
#' @param df_long  Long tibble with date, label, value (quarterly).
#' @param name_from Column whose values become the new column names.
pivot_quarterly_wide <- function(df_long, name_from = "label") {
  df_long |>
    tidyr::pivot_wider(
      id_cols     = date,
      names_from  = !!name_from,
      values_from = value
    ) |>
    dplyr::arrange(date)
}

#' Compute YoY (4-quarter) and QoQ (1-quarter) percentage changes for the
#' numeric columns in a wide quarterly panel.
#'
#' Output column naming: `<var>_yoy` and `<var>_qoq` (decimal, not %).
#'
#' @param df_wide Wide quarterly tibble with `date` as the time column.
#' @param vars    Character vector of column names to transform. Defaults
#'                to all numeric columns other than `date`.
calculate_growth_rates <- function(df_wide, vars = NULL) {

  if (is.null(vars)) {
    vars <- setdiff(names(df_wide)[vapply(df_wide, is.numeric, logical(1))],
                    "date")
  }

  out <- df_wide |> dplyr::arrange(date)

  for (v in vars) {
    yoy_col <- paste0(v, "_yoy")
    qoq_col <- paste0(v, "_qoq")
    x <- out[[v]]
    out[[yoy_col]] <- (x / dplyr::lag(x, 4L)) - 1
    out[[qoq_col]] <- (x / dplyr::lag(x, 1L)) - 1
  }
  out
}

#' Compute trade-balance / net-export derived measures.
#'
#' Requires the wide panel to have `Exports` and `Imports` columns (the
#' labels assigned in `01_get_data.R`).
add_trade_derived <- function(df_wide) {
  required <- c("Exports", "Imports")
  missing  <- setdiff(required, names(df_wide))
  if (length(missing)) {
    stop("Missing required columns for trade derived measures: ",
         paste(missing, collapse = ", "), call. = FALSE)
  }

  df_wide |>
    dplyr::mutate(
      NetExports       = Exports - Imports,
      TradeBalanceRatio = NetExports / (Exports + Imports)
    )
}

#' Add commodity-specific transformations (log price, quarterly change).
add_oil_derived <- function(df_wide,
                            oil_col = "OilWTI") {
  if (!oil_col %in% names(df_wide)) {
    warning("Oil column not present; skipping oil-derived measures.")
    return(df_wide)
  }
  df_wide |>
    dplyr::mutate(
      OilWTI_log    = log(.data[[oil_col]]),
      OilWTI_change = .data[[oil_col]] - dplyr::lag(.data[[oil_col]], 1L)
    )
}

#' Compute implicit trade deflators from nominal and real trade levels.
#'
#' Implicit deflator = nominal level / real level x 100. This recovers a
#' chained Paasche-style price index for traded goods and services without
#' needing a separately published BLS import/export price index. The deflator
#' is the price object that exchange-rate movements pass through to.
#'
#' @param df_wide Wide quarterly panel containing nominal and real trade
#'   columns (`Exports`, `RealExports`, `Imports`, `RealImports`).
add_trade_deflators <- function(df_wide) {
  needed <- c("Exports", "RealExports", "Imports", "RealImports")
  missing <- setdiff(needed, names(df_wide))
  if (length(missing)) {
    warning("Skipping trade deflators; missing columns: ",
            paste(missing, collapse = ", "))
    return(df_wide)
  }

  df_wide |>
    dplyr::mutate(
      ImportDeflator = (Imports / RealImports) * 100,
      ExportDeflator = (Exports / RealExports) * 100,
      TermsOfTrade   = ExportDeflator / ImportDeflator,
      RealNetExports = RealExports - RealImports
    )
}
