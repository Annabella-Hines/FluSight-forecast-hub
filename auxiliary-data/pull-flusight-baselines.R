
# Script that runs with the Pull baselines action to download and save the weekly baselines from the FluSight-baseline repository.
# Retrieves specifically FluSight-baseline, FluSight-base_seasonal, and FluSight-equal_cat.

# load package
library(lubridate)
library(hubValidations)
library(fs)

# Get last Saturday
current_ref_date <- ceiling_date(Sys.Date(), "week") - days(1)
date_str <- format(current_ref_date, "%Y-%m-%d")

# Types and their source folders
baseline_types <- c("FluSight-baseline", "FluSight-base_seasonal", "FluSight-equal_cat")
baseline_folders <- c("Flusight-baseline", "Flusight-seasonal-baseline", "Flusight-equal_cat")

# Keep track of failed validations
validation_errors <- list()

# Loop and download each one
for (i in seq_along(baseline_types)) {
  type <- baseline_types[i]
  folder <- baseline_folders[i]
  filename <- paste0(date_str, "-", type, ".csv")
  
  # Construct URL and destination
  file_url <- paste0(
    "https://raw.githubusercontent.com/cdcepi/Flusight-baseline/main/weekly-submission/forecasts/",
    folder, "/", filename
  )
  target_dir <- file.path("model-output", type)
  dir_create(target_dir, recurse = TRUE)
  destfile <- file.path(target_dir, filename)
  
  # Download
  download_success <- tryCatch({
    download.file(url = file_url, destfile = destfile, method = "libcurl")
    cat("✅ Downloaded and saved:", destfile, "\n")
    TRUE
  }, error = function(e) {
    cat("❌ Failed to download", filename, "\nReason:", e$message, "\n")
    FALSE
  })
  
  # Validate only if download succeeded
  if (download_success) {
    cat("🔍 Validating:", destfile, "\n")
    validation_result <- tryCatch({
      v <- hubValidations::validate_file_local(destfile)
      if (!v$valid) {
        cat("❌ Validation failed for", destfile, "\n")
        validation_errors[[length(validation_errors) + 1]] <- list(file = destfile, error = "Invalid file format or content.")
      } else {
        cat("✅ Validation passed for", destfile, "\n")
      }
    }, error = function(e) {
      cat("❌ Error validating", destfile, ":", e$message, "\n")
      validation_errors[[length(validation_errors) + 1]] <- list(file = destfile, error = e$message)
    })
  }
}

# Stop script if any validations failed
if (length(validation_errors) > 0) {
  cat("\n⚠️ Some files failed validation:\n")
  for (err in validation_errors) {
    cat(" -", err$file, ":", err$error, "\n")
  }
  quit(status = 1)
} else {
  cat("\n✅ All downloaded baseline forecasts passed validation.\n")
}

