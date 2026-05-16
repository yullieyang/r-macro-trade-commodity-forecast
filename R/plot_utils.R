# R/plot_utils.R
# ggplot2 helpers used by 03_exploratory_analysis.R and 04_forecast_model.R.

suppressPackageStartupMessages({
  library(ggplot2)
  library(scales)
  library(dplyr)
  library(tidyr)
})

#' Standard project theme: minimal, serif-friendly, print-safe.
theme_macro <- function(base_size = 11) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title       = ggplot2::element_text(face = "bold"),
      plot.subtitle    = ggplot2::element_text(color = "grey30"),
      plot.caption     = ggplot2::element_text(color = "grey40", hjust = 0),
      strip.text       = ggplot2::element_text(face = "bold"),
      panel.grid.minor = ggplot2::element_blank(),
      legend.position  = "bottom"
    )
}

#' Multi-panel overview chart of the headline indicators.
#'
#' @param df_long Long tibble (date, label, value).
#' @param vars    Character vector of labels to include, in panel order.
create_overview_plot <- function(df_long, vars) {

  df_plot <- df_long |>
    dplyr::filter(label %in% vars) |>
    dplyr::mutate(label = factor(label, levels = vars))

  ggplot2::ggplot(df_plot, ggplot2::aes(date, value)) +
    ggplot2::geom_line(color = "#1f4e79", linewidth = 0.5) +
    ggplot2::facet_wrap(~ label, scales = "free_y", ncol = 2) +
    ggplot2::scale_x_date(date_breaks = "5 years", date_labels = "%Y") +
    ggplot2::labs(
      title    = "U.S. macro, trade, and commodity indicators",
      subtitle = "Quarterly frequency; period-average aggregation",
      x        = NULL,
      y        = NULL,
      caption  = "Source: FRED."
    ) +
    theme_macro()
}

#' Net-exports trend chart with a zero reference line.
create_net_exports_plot <- function(df_wide) {
  ggplot2::ggplot(df_wide, ggplot2::aes(date, NetExports)) +
    ggplot2::geom_hline(yintercept = 0, color = "grey40", linewidth = 0.3) +
    ggplot2::geom_line(color = "#9c1f1f", linewidth = 0.6) +
    ggplot2::scale_y_continuous(labels = scales::label_dollar(suffix = "B")) +
    ggplot2::scale_x_date(date_breaks = "5 years", date_labels = "%Y") +
    ggplot2::labs(
      title    = "U.S. net exports of goods and services",
      subtitle = "Exports minus imports, billions of dollars, quarterly",
      x        = NULL,
      y        = "Net exports",
      caption  = "Source: FRED (EXPGS, IMPGS)."
    ) +
    theme_macro()
}

#' Correlation heatmap across selected numeric variables.
create_correlation_plot <- function(df_wide, vars) {

  mat <- df_wide |>
    dplyr::select(dplyr::all_of(vars)) |>
    stats::cor(use = "pairwise.complete.obs")

  corr_long <- as.data.frame(as.table(mat))
  names(corr_long) <- c("var_x", "var_y", "corr")

  ggplot2::ggplot(corr_long,
                  ggplot2::aes(var_x, var_y, fill = corr)) +
    ggplot2::geom_tile(color = "white") +
    ggplot2::geom_text(
      ggplot2::aes(label = sprintf("%.2f", corr)),
      size = 3
    ) +
    ggplot2::scale_fill_gradient2(
      low      = "#9c1f1f",
      mid      = "white",
      high     = "#1f4e79",
      midpoint = 0,
      limits   = c(-1, 1),
      name     = "Correlation"
    ) +
    ggplot2::labs(
      title    = "Co-movement of oil, trade, and macro variables",
      subtitle = "Pearson correlations on quarterly levels",
      x        = NULL, y = NULL,
      caption  = "Source: FRED. Pairwise-complete observations."
    ) +
    theme_macro() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 35, hjust = 1)
    )
}

#' Plot a `forecast::forecast` object as a tidy ggplot with shaded intervals.
#'
#' @param hist_df  Historical tibble with `date` and `value` columns.
#' @param fc       Object returned by `forecast::forecast()`.
#' @param var_name Title-friendly name of the forecasted variable.
create_forecast_plot <- function(hist_df, fc, var_name) {

  # Convert ts-based forecast object into a date-indexed tibble.
  fc_start <- max(hist_df$date) + months(3)
  fc_dates <- seq.Date(from = fc_start, by = "3 months",
                       length.out = length(fc$mean))

  fc_df <- tibble::tibble(
    date  = fc_dates,
    point = as.numeric(fc$mean),
    lo80  = as.numeric(fc$lower[, 1]),
    hi80  = as.numeric(fc$upper[, 1]),
    lo95  = as.numeric(fc$lower[, 2]),
    hi95  = as.numeric(fc$upper[, 2])
  )

  ggplot2::ggplot() +
    ggplot2::geom_line(
      data = hist_df,
      ggplot2::aes(date, value),
      color = "grey20", linewidth = 0.5
    ) +
    ggplot2::geom_ribbon(
      data = fc_df,
      ggplot2::aes(date, ymin = lo95, ymax = hi95),
      fill = "#1f4e79", alpha = 0.15
    ) +
    ggplot2::geom_ribbon(
      data = fc_df,
      ggplot2::aes(date, ymin = lo80, ymax = hi80),
      fill = "#1f4e79", alpha = 0.30
    ) +
    ggplot2::geom_line(
      data = fc_df,
      ggplot2::aes(date, point),
      color = "#1f4e79", linewidth = 0.6
    ) +
    ggplot2::scale_x_date(date_breaks = "5 years", date_labels = "%Y") +
    ggplot2::labs(
      title    = sprintf("Forecast: %s", var_name),
      subtitle = "Shaded bands: 80% (darker) and 95% prediction intervals",
      x        = NULL,
      y        = var_name,
      caption  = "Model: auto.arima on quarterly history. Source: FRED."
    ) +
    theme_macro()
}

#' Save a ggplot object as PNG with consistent dimensions.
save_figure <- function(plot, path,
                        width = 8, height = 5, dpi = 200) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  ggplot2::ggsave(
    filename = path, plot = plot,
    width = width, height = height, dpi = dpi, units = "in"
  )
  invisible(path)
}
