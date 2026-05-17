# Tests for R/passthrough_utils.R
#
# The pass-through helpers turn a wide quarterly panel into a regression
# panel of log-differences and fit a distributed-lag OLS. These tests use
# small synthetic panels with known relationships so the math is auditable.

suppressPackageStartupMessages({
  library(testthat)
  library(dplyr)
  library(tibble)
})

# ---- prep_passthrough_panel -------------------------------------------------

test_that("prep_passthrough_panel computes log-diffs and FX lags", {
  panel <- tibble::tibble(
    date           = seq(as.Date("2020-01-01"), by = "quarter", length.out = 12),
    ImportDeflator = seq(100, 122, length.out = 12),
    USDIndex       = seq(120, 100, length.out = 12),
    CPI            = seq(250, 270, length.out = 12)
  )

  out <- prep_passthrough_panel(panel, max_lag = 2L)

  expect_true(all(c("dlog_price", "dlog_fx",
                    "dlog_fx_lag1", "dlog_fx_lag2",
                    "dlog_cpi") %in% names(out)))
  # dlog_price uses log(price_t) - log(price_{t-1}); with the lag and
  # drop_na we lose the first observations (1 for the level diff, plus
  # max_lag for the FX lags), so 12 - 3 = 9 observations remain.
  expect_equal(nrow(out), 12L - 3L)
})

test_that("prep_passthrough_panel errors when a required column is missing", {
  bad <- tibble::tibble(
    date           = seq(as.Date("2020-01-01"), by = "quarter", length.out = 6),
    ImportDeflator = 100:105
    # missing USDIndex and CPI
  )
  expect_error(prep_passthrough_panel(bad), "USDIndex")
})

# ---- fit_passthrough_lm -----------------------------------------------------

test_that("fit_passthrough_lm recovers a known pass-through coefficient", {
  # Build a panel where Δlog(price) = 0.4 * Δlog(fx) + small noise.
  set.seed(20260517)
  n <- 200
  dlog_fx_true <- rnorm(n, sd = 0.02)
  dlog_price_true <- 0.4 * dlog_fx_true + rnorm(n, sd = 0.001)

  # Rebuild a level series from the diffs so prep_passthrough_panel can
  # re-derive them. Start values are arbitrary; the test only cares about
  # the slope.
  log_fx    <- cumsum(c(log(120), dlog_fx_true))
  log_price <- cumsum(c(log(100), dlog_price_true))
  log_cpi   <- cumsum(c(log(250), rnorm(n, sd = 0.002)))

  panel <- tibble::tibble(
    date           = seq(as.Date("1980-01-01"), by = "quarter", length.out = n + 1L),
    ImportDeflator = exp(log_price),
    USDIndex       = exp(log_fx),
    CPI            = exp(log_cpi)
  )

  prep <- prep_passthrough_panel(panel, max_lag = 0L)
  fit  <- fit_passthrough_lm(prep, max_lag = 0L)

  # The cumulative pass-through with max_lag = 0 is just the contemporaneous
  # beta on dlog_fx. With this much data the recovered slope should be very
  # close to the data-generating 0.4.
  expect_equal(fit$cumulative_passthrough, 0.4, tolerance = 0.05)
  expect_gt(fit$n_obs, 100L)
  expect_true("term" %in% names(fit$tidy))
})

# ---- tidy_passthrough -------------------------------------------------------

test_that("tidy_passthrough attaches target and meta columns", {
  panel <- tibble::tibble(
    date           = seq(as.Date("2010-01-01"), by = "quarter", length.out = 40),
    ImportDeflator = exp(cumsum(c(log(100), rnorm(39, sd = 0.01)))),
    USDIndex       = exp(cumsum(c(log(120), rnorm(39, sd = 0.01)))),
    CPI            = exp(cumsum(c(log(250), rnorm(39, sd = 0.005))))
  )
  prep <- prep_passthrough_panel(panel, max_lag = 1L)
  fit  <- fit_passthrough_lm(prep, max_lag = 1L)
  tidy <- tidy_passthrough(fit, target_label = "ImportDeflator")

  expect_true(all(c("target", "cumulative_passthrough", "n_obs") %in% names(tidy)))
  expect_true(all(tidy$target == "ImportDeflator"))
})
