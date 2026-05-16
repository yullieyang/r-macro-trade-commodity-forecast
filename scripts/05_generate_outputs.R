# scripts/05_generate_outputs.R
# Stage 5: End-to-end orchestrator. Runs stages 01 -> 04 in sequence so a
# reviewer can reproduce every artifact in `data/` and `outputs/` with a
# single call from the project root:
#
#   source(here::here("scripts", "05_generate_outputs.R"))
#
# Each stage script is self-contained and can also be run independently.

suppressPackageStartupMessages({
  library(here)
})

run_stage <- function(script_name) {
  path <- here::here("scripts", script_name)
  message("\n>>> Running ", script_name)
  t0 <- Sys.time()
  source(path, local = new.env(parent = globalenv()), echo = FALSE)
  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  message(sprintf("    completed in %.1fs", elapsed))
}

stages <- c(
  "01_get_data.R",
  "02_clean_transform_data.R",
  "03_exploratory_analysis.R",
  "04_forecast_model.R"
)

message("Pipeline start: ", Sys.time())
for (s in stages) run_stage(s)
message("\nPipeline finished: ", Sys.time())
message("All outputs are under data/processed/ and outputs/.")
