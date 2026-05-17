# Test runner for the flagship pipeline helpers.
#
# Run interactively with: testthat::test_dir("tests/testthat")
# Run from the shell with: Rscript -e 'testthat::test_dir("tests/testthat")'
# CI invokes this file directly via `Rscript tests/testthat.R`.

library(testthat)

# Source helpers from R/ instead of devtools::load_all() so the suite works
# in a non-package layout. Order matters: data_utils -> transform_utils ->
# passthrough_utils, since later helpers can reference earlier ones.
helper_files <- list.files(
  here::here("R"),
  pattern = "\\.R$",
  full.names = TRUE
)
invisible(lapply(helper_files, source))

testthat::test_dir(here::here("tests", "testthat"), stop_on_failure = TRUE)
