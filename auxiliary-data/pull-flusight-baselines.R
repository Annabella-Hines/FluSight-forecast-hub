# Load required libraries
library(lubridate)
library(hubValidations)
library(fs)

# Prepare output file for PR body
result_file <- "validation_result.md"

# Wrap everything in a top-level error handler
tryCatch({

  # Set up reference date and forecast filenames
  current_ref_date <- ceiling_date(Sys.Date(), "week") - days(1)
  date_str <- format(current_ref_date, "%Y-%m-%d")

  baseline_types <- c("FluSight-baseline", "FluSight-base_seasonal", "FluSight-equal_cat")
  baseline_folders <- c("Flusight-baseline", "Flusight-seasonal-baseline", "Flusight-equal_cat")

  validation_messages <- c("### 🧪 Validation Results")

  for (i in seq_along(baseline_types)) {
    type <- baseline_types[i]
    folder <- baseline_folders[i]
    filename <- paste0(date_str, "-", type, ".csv")

    # Build URL and destination
    file_url <- paste0(
      "https://raw.githubusercontent.com/cdcepi/Flusight-baseline/main/weekly-submission/forecasts/",
      folder, "/", filename
    )

    target_dir <- file.path("model-output", type)
    dir_create(target_dir, recurse = TRUE)
    destfile <- file.path(target_dir, filename)
    rel_path <- file.path(type, filename)

    # Attempt download
    download_success <- tryCatch({
      download.file(url = file_url, destfile = destfile, method = "libcurl")
      cat("✅ Downloaded and saved:", destfile, "\n")
      TRUE
    }, error = function(e) {
      cat("❌ Failed to download", filename, "\nReason:", e$message, "\n")
      validation_messages <- c(validation_messages, paste0("❌ **", rel_path, "**: Failed to download (", e$message, ")"))
      FALSE
    })

    # Attempt validation if file was downloaded
    if (download_success) {
      cat("🔍 Validating:", destfile, "\n")
      tryCatch({
        v <- hubValidations::validate_submission(hub_path = ".", file_path = rel_path)

        # Try extracting individual error messages
        error_report <- tryCatch({
          errors <- hubValidations::check_for_errors(v, verbose = FALSE)
          if (length(errors$errors) > 0) {
            paste0("❌ **", rel_path, "**:\n- ", paste(errors$errors, collapse = "\n- "))
          } else {
            paste0("✅ **", rel_path, "** passed validation.")
          }
        }, error = function(e) {
          paste0("❌ **", rel_path, "**:\n", e$message)
        })

        validation_messages <- c(validation_messages, error_report)

      }, error = function(e) {
        msg <- paste0("❌ **", rel_path, "**:\n", e$message)
        validation_messages <- c(validation_messages, msg)
      })
    }
  }

  # Write markdown to file
  writeLines(validation_messages, result_file)

}, error = function(e) {
  # Fallback if something top-level crashes
  writeLines(c("### 🧪 Validation Results", "❌ Script crashed:", e$message), result_file)
})
