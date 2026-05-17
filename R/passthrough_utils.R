# R/passthrough_utils.R
# Helpers for the exchange-rate pass-through analysis.
#
# Pass-through asks: when the dollar moves, how much of that change is
# absorbed into prices charged for U.S. imports (or exports) versus how
# much shows up as quantity adjustment? Standard finding in the
# international-trade literature is that short-run pass-through is well
# below one — i.e. dollar moves are NOT fully reflected in trade prices.
# This helper estimates that pass-through coefficient.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(tibble)
  library(broom)
})

#' Build a regression-ready panel of log-differences.
#'
#' @param df_wide Wide quarterly panel.
#' @param price_col Trade-price column to use as the dependent variable
#'   (default: ImportDeflator).
#' @param fx_col Exchange-rate column (default: USDIndex).
#' @param control_cols Additional controls to lag-difference (default: CPI).
#' @param max_lag Number of FX lags to include (default 4 quarters).
#'
#' Returns a tibble with columns: `date`, `dlog_price`, `dlog_fx`,
#' `dlog_fx_lag1` ... `dlog_fx_lag{max_lag}`, plus control diffs.
prep_passthrough_panel <- function(df_wide,
                                   price_col    = "ImportDeflator",
                                   fx_col       = "USDIndex",
                                   control_cols = c("CPI"),
                                   max_lag      = 4L) {

  cols <- c(price_col, fx_col, control_cols)
  miss <- setdiff(cols, names(df_wide))
  if (length(miss)) {
    stop("Pass-through panel missing columns: ",
         paste(miss, collapse = ", "), call. = FALSE)
  }

  out <- df_wide |>
    dplyr::arrange(date) |>
    dplyr::mutate(
      dlog_price = log(.data[[price_col]]) - dplyr::lag(log(.data[[price_col]]), 1L),
      dlog_fx    = log(.data[[fx_col]])    - dplyr::lag(log(.data[[fx_col]]),    1L)
    )

  # Add FX lags.
  for (k in seq_len(max_lag)) {
    out[[paste0("dlog_fx_lag", k)]] <- dplyr::lag(out$dlog_fx, k)
  }

  # Add control diffs.
  for (c in control_cols) {
    diff_name <- paste0("dlog_", tolower(c))
    out[[diff_name]] <- log(out[[c]]) - dplyr::lag(log(out[[c]]), 1L)
  }

  out |>
    dplyr::select(date, dlog_price, dlog_fx,
                  dplyr::starts_with("dlog_fx_lag"),
                  dplyr::starts_with("dlog_")) |>
    dplyr::distinct(date, .keep_all = TRUE) |>
    tidyr::drop_na()
}

#' Fit the pass-through regression.
#'
#' Δlog(price) = α + Σ_{k=0..K} β_k · Δlog(FX)_{t-k} + γ · Δlog(CPI) + ε
#'
#' @param panel Output of `prep_passthrough_panel()`.
#' @param max_lag Highest FX lag included as a regressor.
#' @return List with `model` (lm fit), `tidy` (coefficient table),
#'   `cumulative_passthrough`, and `n_obs`.
fit_passthrough_lm <- function(panel, max_lag = 4L) {

  # paste0("x", integer(0)) recycles to "x" (a known R quirk), so guard the
  # zero-lag case explicitly instead of relying on the paste0 to produce
  # character(0).
  fx_lag_terms  <- if (max_lag > 0L) paste0("dlog_fx_lag", seq_len(max_lag)) else character(0)
  fx_terms      <- c("dlog_fx", fx_lag_terms)
  control_terms <- setdiff(grep("^dlog_", names(panel), value = TRUE),
                           c("dlog_price", fx_terms))

  rhs <- paste(c(fx_terms, control_terms), collapse = " + ")
  fml <- stats::as.formula(paste("dlog_price ~", rhs))

  fit  <- stats::lm(fml, data = panel)
  tidy <- broom::tidy(fit, conf.int = TRUE) |>
    dplyr::mutate(is_fx = grepl("^dlog_fx", term))

  cum_pt <- sum(tidy$estimate[tidy$is_fx])

  list(
    model                  = fit,
    tidy                   = tidy,
    cumulative_passthrough = cum_pt,
    n_obs                  = length(stats::resid(fit))
  )
}

#' Tidy summary table for one pass-through fit.
#'
#' Adds a `target` column so multiple fits (e.g. import vs export deflator)
#' can be row-bound for a single combined output.
tidy_passthrough <- function(fit_obj, target_label) {
  fit_obj$tidy |>
    dplyr::mutate(
      target                 = target_label,
      cumulative_passthrough = fit_obj$cumulative_passthrough,
      n_obs                  = fit_obj$n_obs,
      .before                = 1L
    )
}
