# R/model_utils.R
# Forecasting and model-summary helpers.

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
  library(broom)
  library(forecast)
})

#' Convert a date-indexed tibble into a quarterly ts object.
#'
#' @param df  Tibble with `date` (Date) and `value` columns.
#' @param freq Numeric frequency for `ts()`. Default 4 = quarterly.
as_quarterly_ts <- function(df, freq = 4) {
  df <- df |> dplyr::filter(!is.na(value)) |> dplyr::arrange(date)
  if (nrow(df) == 0L) stop("No non-missing observations to convert.", call. = FALSE)
  start_year <- as.integer(format(df$date[1], "%Y"))
  start_qtr  <- as.integer(format(df$date[1], "%m"))
  start_qtr  <- (start_qtr - 1L) %/% 3L + 1L
  stats::ts(df$value, start = c(start_year, start_qtr), frequency = freq)
}

#' Fit an auto-selected ARIMA model and produce an h-step forecast.
#'
#' @param series_ts ts object (quarterly).
#' @param h         Forecast horizon (quarters).
#' @return A list with `model`, `forecast`, and `tidy_summary`.
fit_arima_forecast <- function(series_ts, h = 8L) {

  model <- forecast::auto.arima(
    series_ts,
    seasonal  = TRUE,
    stepwise  = FALSE,
    approximation = FALSE
  )

  fc <- forecast::forecast(model, h = h, level = c(80, 95))

  list(
    model        = model,
    forecast     = fc,
    tidy_summary = tidy_arima(model)
  )
}

#' Tidy an Arima model into a coefficient table with SEs and p-values.
tidy_arima <- function(model) {
  coefs <- stats::coef(model)
  if (length(coefs) == 0L) {
    return(tibble::tibble(
      term      = character(),
      estimate  = numeric(),
      std_error = numeric(),
      z         = numeric(),
      p_value   = numeric()
    ))
  }
  ses <- sqrt(diag(model$var.coef))
  z   <- coefs / ses
  tibble::tibble(
    term      = names(coefs),
    estimate  = as.numeric(coefs),
    std_error = as.numeric(ses),
    z         = as.numeric(z),
    p_value   = 2 * stats::pnorm(-abs(z))
  )
}

#' Turn a `forecast::forecast` object into a tidy results tibble.
#'
#' @param hist_df Historical tibble (date, value) used to derive forecast dates.
#' @param fc      forecast object.
forecast_to_tibble <- function(hist_df, fc) {
  fc_start <- max(hist_df$date) + months(3)
  fc_dates <- seq.Date(from = fc_start, by = "3 months",
                       length.out = length(fc$mean))
  tibble::tibble(
    date       = fc_dates,
    point      = as.numeric(fc$mean),
    lower_80   = as.numeric(fc$lower[, 1]),
    upper_80   = as.numeric(fc$upper[, 1]),
    lower_95   = as.numeric(fc$lower[, 2]),
    upper_95   = as.numeric(fc$upper[, 2])
  )
}

#' Save a model summary (coefficients + fit diagnostics) as CSV.
#'
#' Adds AIC / BIC / sigma^2 as additional rows so the CSV is fully
#' self-describing and consumable by non-R reviewers (Excel, BI tools).
save_model_summary <- function(model, tidy_df, path) {

  diagnostics <- tibble::tibble(
    term      = c("aic", "bic", "sigma_sq", "log_likelihood", "n_obs"),
    estimate  = c(stats::AIC(model),
                  stats::BIC(model),
                  model$sigma2,
                  as.numeric(stats::logLik(model)),
                  as.numeric(model$nobs)),
    std_error = NA_real_,
    z         = NA_real_,
    p_value   = NA_real_
  )

  out <- dplyr::bind_rows(tidy_df, diagnostics)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(out, path)
  invisible(path)
}
