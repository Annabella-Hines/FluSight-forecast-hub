# Load required libraries
library(lubridate)
library(hubValidations)
library(fs)

# Prepare output file for PR body
result_file <- "validation_result.md"

# Set up date and file paths
current_ref_date <- ceiling_date(Sys.Date(), "week") - days(1)
date_str <- format(current_ref_date, "%Y-%m-%d")

baseline_types <- c("FluSight-baseline", "FluSight-base_seasonal", "FluSight-equal_cat")
baseline_folders <- c("Flusight-baseline", "Flusight-seasonal-baseline", "Flusight-equal_cat")

validation_messages <- c()

for (i in seq_along(baseline_types)) {
  type <- baseline_types[i]
  folder <- baseline_folders[i]
  filename <- paste0(date_str, "-", type, ".csv")
  file_url <- paste0(
    "https://raw.githubusercontent.com/cdcepi/Flusight-baseline/main/weekly-submission/forecasts/",
    folder, "/", filename
  )

  target_dir <- file.path("model-output", type)
  dir_create(target_dir, recurse = TRUE)
  destfile <- file.path(target_dir, filename)

  # Download the file
  download_success <- tryCatch({
    download.file(url = file_url, destfile = destfile, method = "libcurl")
    cat("✅ Downloaded:", destfile, "\n")
    TRUE
  }, error = function(e) {
    cat("❌ Failed to download", filename, ":", e$message, "\n")
    FALSE
  })

  # Validate the file
  if (download_success) {
    rel_path <- file.path(type, filename)
    v <- tryCatch({
      result <- hubValidations::validate_submission(hub_path = ".", file_path = rel_path)
      hubValidations::check_for_errors(result)
      paste0("✅ **", rel_path, "** passed validation.")
    }, error = function(e) {
      paste0("❌ **", rel_path, "**:\n\n", e$message)
    })

    validation_messages <- c(validation_messages, v)
  }
}

# Write validation summary to markdown
writeLines(c("### 🧪 Validation Results", validation_messages), result_file)
