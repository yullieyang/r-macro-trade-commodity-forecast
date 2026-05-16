# R/io_utils.R
# Small I/O conveniences shared across pipeline stages.

suppressPackageStartupMessages({
  library(readr)
  library(here)
})

#' Resolve a path inside the project root using `here::here()`.
#'
#' Thin wrapper that fails loudly if the caller has not initialized `here`
#' (i.e. is not running from inside the project).
proj_path <- function(...) {
  here::here(...)
}

#' Write a tibble as CSV, ensuring the parent directory exists.
write_csv_safe <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(data, path)
  invisible(path)
}

#' Read a CSV with date parsing for a `date` column.
read_csv_safe <- function(path) {
  if (!file.exists(path)) {
    stop("File not found: ", path, call. = FALSE)
  }
  readr::read_csv(path, show_col_types = FALSE)
}

#' Source every .R file inside the project's R/ directory.
#'
#' Avoids requiring this project to be a full R package while still letting
#' each pipeline script pull in shared helpers with one call.
source_project_helpers <- function() {
  helper_files <- list.files(
    proj_path("R"), pattern = "\\.R$", full.names = TRUE
  )
  # Source this file last so we don't infinitely recurse.
  helper_files <- setdiff(helper_files, normalizePath(sys.frame(1)$ofile %||% ""))
  invisible(lapply(helper_files, source, chdir = FALSE))
}

# Null-coalescing operator (R has no built-in).
`%||%` <- function(a, b) if (is.null(a)) b else a
