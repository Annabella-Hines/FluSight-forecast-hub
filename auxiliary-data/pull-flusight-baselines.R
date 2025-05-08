# Load required libraries
library(lubridate)
library(hubValidations)
library(fs)

# Prepare output file for PR body
result_file <- "validation_result.md"

# Wrap entire script to catch any unexpected errors
tryCatch({

  # Set up date and file paths
  current_ref_date <- ceiling_date(Sys.Date(), "week") - days(1)
  date_str <- format(current_ref_date, "%Y-%m-%d")

  baseline_types <- c("FluSight-baseline", "FluSight-base_seasonal", "FluSight-equal_cat")
  baseline_folders <- c("Flusight-baseline", "Flusight-seasonal-baseline", "Flusight-equal_cat")

  downloaded_files <- c()  # Keep track of successfully downloaded files

  for (i in seq_along(baseline_types)) {
    type <- baseline_types[i]
    folder <- baseline_folders[i]
    filename <- paste0(date_str, "-", type, ".csv")

    file_url <- paste0(
      "https://raw.githubusercontent.com/cdcepi/Flusight-baseline/main/weekly-submission/forecasts/",
      folder, "/", filename
    )

    target_dir <- file.path("model-output", type)
    dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)
    destfile <- file.path(target_dir, filename)

    # Attempt to download file
    download_success <- tryCatch({
      download.file(url = file_url, destfile = destfile, method = "libcurl")
      cat("✅ Downloaded and saved:", destfile, "\n")
      downloaded_files <- c(downloaded_files, file.path(type, filename))  # Relative path
      TRUE
    }, error = function(e) {
      cat("❌ Failed to download", filename, "\nReason:", e$message, "\n")
      FALSE
    })
  }

  # Now validate each successfully downloaded file
  messages <- c()
  has_errors <- FALSE

  for (file in downloaded_files) {
    cat("🔍 Validating:", file, "\n")
    result <- tryCatch({
      v <- hubValidations::validate_submission(hub_path = ".", path = file)
      errors <- hubValidations::check_for_errors(v, verbose = TRUE, stop_on_error = FALSE)
      if (length(errors$errors) > 0) {
        has_errors <<- TRUE
        paste0("❌ **", file, "**: ", paste(errors$errors, collapse = "; "))
      } else {
        paste0("✅ **", file, "** passed validation.")
      }
    }, error = function(e) {
      has_errors <<- TRUE
      paste0("❌ **", file, "**: ", e$message)
    })
    messages <- c(messages, result)
  }

  # Write validation result to markdown
  writeLines(c("### 🧪 Validation Results", messages), result_file)

}, error = function(e) {
  # Catch-all to ensure script doesn't silently fail
  writeLines(c(
    "### ❌ Script crashed",
    "",
    paste0("```\n", e$message, "\n```")
  ), result_file)
  stop(e)  # Optional: re-throw if you want GitHub to fail the job
})

