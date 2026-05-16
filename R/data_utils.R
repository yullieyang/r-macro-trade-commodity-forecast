# R/data_utils.R
# Helpers for retrieving and snapshotting FRED series.
#
# All functions here are pure with respect to disk: they either return a
# tibble or write a CSV at an explicit path. No global state is modified.

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
  library(readr)
  library(fredr)
  library(here)
})

#' Retrieve a single FRED series as a tidy tibble.
#'
#' Thin wrapper around `fredr::fredr()` that standardizes column names and
#' attaches a human-readable label. Errors are converted into a warning and
#' an empty tibble so a single failing series does not abort the whole pull.
#'
#' @param series_id  FRED series identifier, e.g. "GDPC1".
#' @param label      Short human-readable name used in plots and tables.
#' @param start_date Earliest observation date to request (Date or string).
#' @return A tibble with columns: date, series_id, label, value.
get_fred_series <- function(series_id,
                            label,
                            start_date = as.Date("1990-01-01")) {

  stopifnot(is.character(series_id), length(series_id) == 1L)
  stopifnot(is.character(label), length(label) == 1L)

  out <- tryCatch(
    fredr::fredr(
      series_id         = series_id,
      observation_start = as.Date(start_date)
    ),
    error = function(e) {
      warning(sprintf("Failed to fetch %s: %s", series_id, conditionMessage(e)))
      tibble::tibble(date = as.Date(character()), value = numeric())
    }
  )

  out |>
    dplyr::transmute(
      date      = as.Date(date),
      series_id = series_id,
      label     = label,
      value     = as.numeric(value)
    ) |>
    dplyr::arrange(date)
}

#' Pull a named set of FRED series and return them stacked long.
#'
#' @param series_spec A tibble with columns `series_id` and `label`.
#' @param start_date  Earliest observation date.
#' @return Long tibble with one row per (series_id, date).
get_fred_panel <- function(series_spec,
                           start_date = as.Date("1990-01-01")) {

  stopifnot(all(c("series_id", "label") %in% names(series_spec)))

  purrr_map_dfr(series_spec, function(row) {
    get_fred_series(row$series_id, row$label, start_date = start_date)
  })
}

# Tiny dependency-light row-wise map_dfr so we don't require purrr.
purrr_map_dfr <- function(df, f) {
  rows <- split(df, seq_len(nrow(df)))
  dplyr::bind_rows(lapply(rows, f))
}

#' Persist a long-format FRED snapshot to data/raw/ with a date stamp.
#'
#' @param data Long tibble returned by `get_fred_panel()`.
#' @param path Output CSV path. Parent directory is created if missing.
write_raw_snapshot <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(data, path)
  invisible(path)
}

#' Verify that a FRED API key is available in the environment.
#'
#' Called at the top of `01_get_data.R` to fail fast with a friendly message
#' rather than an opaque fredr error.
require_fred_key <- function() {
  key <- Sys.getenv("FRED_API_KEY", unset = "")
  if (!nzchar(key)) {
    stop(
      "FRED_API_KEY is not set. Copy .Renviron.example to .Renviron, ",
      "add your key, and restart R.",
      call. = FALSE
    )
  }
  fredr::fredr_set_key(key)
  invisible(TRUE)
}
