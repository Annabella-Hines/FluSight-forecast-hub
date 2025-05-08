
# Script that runs with the Pull baselines action to download and save the weekly baselines from the FluSight-baseline repository.
# Retrieves specifically FluSight-baseline, FluSight-base_seasonal, and FluSight-equal_cat.

# load package
library(lubridate)
library(hubValidations)
library(fs)

# Define the reference date
current_ref_date <- ceiling_date(Sys.Date(), "week") - days(1)
date_str <- format(current_ref_date, "%Y-%m-%d")

# Define baseline types and their corresponding folders
baseline_types <- c("FluSight-baseline", "FluSight-base_seasonal", "FluSight-equal_cat")
baseline_folders <- c("Flusight-baseline", "Flusight-seasonal-baseline", "Flusight-equal_cat")

# Initialize a list to track validation errors
validation_errors <- list()

# Loop through each baseline type and folder
for (i in seq_along(baseline_types)) {
  type <- baseline_types[i]
  folder <- baseline_folders[i]
  filename <- paste0(date_str, "-", type, ".csv")
  
  # Construct the file URL
  file_url <- paste0(
    "https://raw.githubusercontent.com/cdcepi/Flusight-baseline/main/weekly-submission/forecasts/",
    folder, "/", filename
  )
  
  # Define the target directory and file path
  target_dir <- file.path("model-output", type)
  dir_create(target_dir, recurse = TRUE)
  destfile <- file.path(target_dir, filename)
  
  # Attempt to download the file
  download_success <- tryCatch({
    download.file(url = file_url, destfile = destfile, method = "libcurl")
    cat("✅ Downloaded and saved:", destfile, "\n")
    TRUE
  }, error = function(e) {
    cat("❌ Failed to download", filename, "\nReason:", e$message, "\n")
    FALSE
  })
  
  # If download is successful, validate the file
  if (download_success) {
    cat("🔍 Validating:", destfile, "\n")
    validation_result <- tryCatch({
      # Assuming 'hub_path' is the path to your hub configuration
      hub_path <- "."
      validate_submission(hub_path,
        file_path = file.path(type, filename)
      ) %>%
        check_for_errors()
      cat("✅ Validation passed for", destfile, "\n")
    }, error = function(e) {
      cat("❌ Error validating", destfile, ":", e$message, "\n")
      validation_errors[[length(validation_errors) + 1]] <- list(file = destfile, error = e$message)
    })
  }
}

# At the end of the script
if (length(validation_errors) > 0) {
  cat("\n⚠️ Some files failed validation:\n")
  msg_lines <- c("### ❌ Validation failed for some files:\n")

  for (err in validation_errors) {
    msg_line <- paste0("- **", err$file, "**: ", err$error)
    msg_lines <- c(msg_lines, msg_line)
    cat(msg_line, "\n")
  }

  # Save the messages to a file that the workflow can read
  writeLines(msg_lines, "validation_result.md")
} else {
  writeLines("✅ All baseline files passed validation.", "validation_result.md")
}
