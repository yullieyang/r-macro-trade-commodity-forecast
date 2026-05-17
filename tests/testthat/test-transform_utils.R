# Tests for R/transform_utils.R
#
# These exercise the small, pure helpers that anchor the pipeline. The goal
# is not 100% coverage — it's to lock down the contracts a reviewer would
# care about: aggregation rules, derived-measure math, and error behavior.

suppressPackageStartupMessages({
  library(testthat)
  library(dplyr)
  library(tibble)
})

# ---- clean_time_series ------------------------------------------------------

test_that("clean_time_series drops NA values, sorts by date, and dedupes", {
  raw <- tibble::tibble(
    date  = as.Date(c("2024-03-31", "2024-01-31", "2024-02-29", "2024-01-31")),
    value = c(2, 1, NA, 1)
  )
  out <- clean_time_series(raw)

  expect_equal(nrow(out), 2L)
  expect_equal(out$date, as.Date(c("2024-01-31", "2024-03-31")))
  expect_equal(out$value, c(1, 2))
})

# ---- to_quarterly -----------------------------------------------------------

test_that("to_quarterly averages monthly observations within a quarter", {
  monthly <- tibble::tibble(
    date  = as.Date(c("2024-01-15", "2024-02-15", "2024-03-15",
                      "2024-04-15", "2024-05-15", "2024-06-15")),
    value = c(10, 20, 30, 40, 50, 60)
  )
  q <- to_quarterly(monthly)

  expect_equal(nrow(q), 2L)
  expect_equal(q$date, as.Date(c("2024-01-01", "2024-04-01")))
  expect_equal(q$value, c(20, 50))  # period averages
})

test_that("to_quarterly is idempotent on already-quarterly inputs", {
  q_in <- tibble::tibble(
    date  = as.Date(c("2024-01-01", "2024-04-01")),
    value = c(100, 110)
  )
  q_out <- to_quarterly(q_in)

  expect_equal(q_out$date, q_in$date)
  expect_equal(q_out$value, q_in$value)
})

# ---- calculate_growth_rates -------------------------------------------------

test_that("calculate_growth_rates computes correct YoY and QoQ", {
  panel <- tibble::tibble(
    date = seq(as.Date("2023-01-01"), as.Date("2024-04-01"), by = "quarter"),
    x    = c(100, 102, 104, 106, 110, 112)
  )
  out <- calculate_growth_rates(panel, vars = "x")

  expect_true(all(c("x_yoy", "x_qoq") %in% names(out)))
  expect_equal(out$x_qoq[2], 102 / 100 - 1, tolerance = 1e-12)
  expect_equal(out$x_yoy[5], 110 / 100 - 1, tolerance = 1e-12)
  # First QoQ and first four YoY values are NA by construction.
  expect_true(is.na(out$x_qoq[1]))
  expect_true(all(is.na(out$x_yoy[1:4])))
})

# ---- add_trade_derived ------------------------------------------------------

test_that("add_trade_derived computes NetExports = Exports - Imports", {
  panel <- tibble::tibble(
    date    = as.Date(c("2024-01-01", "2024-04-01")),
    Exports = c(800, 820),
    Imports = c(1000, 990)
  )
  out <- add_trade_derived(panel)

  expect_equal(out$NetExports, c(-200, -170))
  expect_equal(
    out$TradeBalanceRatio,
    c(-200 / 1800, -170 / 1810),
    tolerance = 1e-12
  )
})

test_that("add_trade_derived errors when required columns are missing", {
  bad <- tibble::tibble(date = as.Date("2024-01-01"), Exports = 1)
  expect_error(add_trade_derived(bad), "Imports")
})

# ---- add_trade_deflators ----------------------------------------------------

test_that("add_trade_deflators recovers the implicit deflator and terms of trade", {
  panel <- tibble::tibble(
    date        = as.Date("2024-01-01"),
    Exports     = 1100,    # nominal
    RealExports = 1000,    # chained real
    Imports     = 1320,    # nominal
    RealImports = 1200     # chained real
  )
  out <- add_trade_deflators(panel)

  # ExportDeflator = 1100/1000 * 100 = 110
  # ImportDeflator = 1320/1200 * 100 = 110
  expect_equal(out$ExportDeflator, 110)
  expect_equal(out$ImportDeflator, 110)
  expect_equal(out$TermsOfTrade, 1)
  expect_equal(out$RealNetExports, 1000 - 1200)
})

test_that("add_trade_deflators warns and returns unchanged when columns missing", {
  bad <- tibble::tibble(date = as.Date("2024-01-01"), Exports = 1)
  expect_warning(out <- add_trade_deflators(bad), "RealExports")
  expect_identical(out, bad)
})
