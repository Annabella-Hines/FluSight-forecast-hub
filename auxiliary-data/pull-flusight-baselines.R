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

  validation_errors <- list()

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

    # Attempt to download file
    download_success <- tryCatch({
      download.file(url = file_url, destfile = destfile, method = "libcurl")
      cat("✅ Downloaded and saved:", destfile, "\n")
      TRUE
    }, error = function(e) {
      cat("❌ Failed to download", filename, "\nReason:", e$message, "\n")
      FALSE
    })

    # If download succeeded, validate
    if (download_success) {
      cat("🔍 Validating:", destfile, "\n")
      tryCatch({
        result <- hubValidations::validate_submission(
          hub_path = ".",  # Assuming the script runs in repo root
          file_path = file.path(type, filename)
        )
        hubValidations::check_for_errors(result)
        cat("✅ Validation passed for", destfile, "\n")
      }, error = function(e) {
        msg <- paste("❌ Error validating", destfile, ":\n", e$message)
        cat(msg, "\n")
        validation_errors[[length(validation_errors) + 1]] <- list(file = destfile, error = e$message)
      })
    }
  }

  # Write results for PR body
  if (length(validation_errors) > 0) {
    msg_lines <- c("### ❌ Validation failed for some files:\n")
    for (err in validation_errors) {
      msg_lines <- c(msg_lines, paste0("- **", err$file, "**: ", err$error))
    }
    writeLines(msg_lines, result_file)
  } else {
    writeLines("✅ All baseline files passed validation.", result_file)
  }

}, error = function(e) {
  # If script crashes, still write something to result file
  msg <- paste("### ❌ Validation script crashed:\n", e$message)
  writeLines(msg, result_file)
  cat(msg, "\n")
})
