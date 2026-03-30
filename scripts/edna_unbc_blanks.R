library(readr)
library(dplyr)
library(openxlsx)

# ---------------------------------------------------------------------------
# Add control blank columns to the UNBC working spreadsheet
#
# Reads the latest edna_for_UNBC file, joins control_blank_field and
# control_blank_office from form_edna by site_id, writes new dated CSV
# and Excel. Push the template repo to trigger m1rr0r sync.
#
# Reusable for future years — update file paths.
# ---------------------------------------------------------------------------

# Inputs
path_form_edna <- "~/Projects/repo/fish_passage_template_reporting/data/backup/2025/form_edna_2025.csv"
path_unbc      <- "~/Projects/repo/fish_passage_template_reporting/data/backup/2025/edna_unbc/edna_for_UNBC_20260218.csv"

# Output — new dated file in same directory
dir_out    <- dirname(path_unbc)
date_out   <- format(Sys.Date(), "%Y%m%d")
path_out_csv  <- file.path(dir_out, paste0("edna_for_UNBC_", date_out, ".csv"))
path_out_xlsx <- file.path(dir_out, paste0("edna_for_UNBC_", date_out, ".xlsx"))

# Read
form_edna <- read_csv(path_form_edna, show_col_types = FALSE)
unbc      <- read_csv(path_unbc, show_col_types = FALSE)

# Extract blank columns, fill NA with FALSE
blanks <- form_edna |>
  select(site_id, control_blank_field, control_blank_office) |>
  filter(!is.na(site_id)) |>
  mutate(
    control_blank_field  = coalesce(control_blank_field, FALSE),
    control_blank_office = coalesce(control_blank_office, FALSE)
  )

# Drop existing blank columns if re-running
unbc <- unbc |>
  select(-any_of(c("control_blank_field", "control_blank_office")))

# Join
unbc_updated <- unbc |>
  left_join(blanks, by = "site_id")

# Verify
cat("Field blanks:", sum(unbc_updated$control_blank_field), "\n")
cat("Office blanks:", sum(unbc_updated$control_blank_office), "\n")
cat("Total rows:", nrow(unbc_updated), "\n")

# Write CSV
write_csv(unbc_updated, path_out_csv)
cat("Wrote:", path_out_csv, "\n")

# Write Excel — match pattern from edna_unbc_plan.R
wb <- createWorkbook()
addWorksheet(wb, "all_samples")
writeData(wb, "all_samples", unbc_updated)
saveWorkbook(wb, path_out_xlsx, overwrite = TRUE)
cat("Wrote:", path_out_xlsx, "\n")
