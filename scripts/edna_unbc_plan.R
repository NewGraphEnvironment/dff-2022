# make map of site vs species ordered by the assay dye order to send to UNBC

# read iin edna form
d_raw <- readr::read_csv(
  "~/Projects/repo/fish_passage_template_reporting/data/backup/2025/form_edna_2025.csv"
) |>
  dplyr::select(
    site_id,
    species_target,
    source
  ) |>
  dplyr::mutate(
    # Replace commas and periods with spaces
    species_target = stringr::str_replace_all(
      species_target, "[,\\.]", " ") |>
      # Collapse multiple spaces into a single space
      stringr::str_replace_all("\\s+", " ") |>
      # Trim leading/trailing spaces
      stringr::str_trim() |>
      # Convert to uppercase
      stringr::str_to_upper(),
    # Map source path to region code (f=Fraser, s=Skeena, m=Mackenzie/Peace)
    region = dplyr::case_when(
      stringr::str_detect(source, "fraser") ~ "f",
      stringr::str_detect(source, "skeena") ~ "s",
      stringr::str_detect(source, "peace") ~ "m",
      TRUE ~ "x"  # unknown
    )
  ) |>
  dplyr::arrange(site_id)

# # Split, reorder by priority (fct_order), and collapse back
# species_target = purrr::map_chr(
#   stringr::str_split(species_target, " "),
#   \(x) paste(intersect(fct_order, x), collapse = " ")
# )
# )

# read in the map of assays
path <- "~/Projects/repo/dff-2022/data/edna_assays.csv"
assay_raw <- readr::read_csv(path) |>
  # last string after dash is the assay_dye unless !is.na(assay_dye)
  dplyr::mutate(
    assay_id  = stringr::str_remove_all(assay_id, "\\s"),
    assay_dye = ifelse(
      is.na(assay_dye),
      stringr::str_extract(assay_id, "(?<=-)[A-Z]+$"),
      assay_dye
    )) |>
  # drop assays explicitly marked as not preferred
  dplyr::filter(is.na(assay_not_preferred) | !assay_not_preferred)

# now our goal is to run species together with equivalent dye types (fam or vic) and
# not mix dies if not necessary.  We don't really want to used something if it is not preferred though
site_species <- d_raw |>
  dplyr::mutate(
    # normalize spacing just in case
    species_target = stringr::str_squish(species_target)
  ) |>
  tidyr::separate(
    col  = species_target,
    into = paste0("sp", 1:4),  # enough slots for "BT CH CO RB"
    sep  = " ",
    fill = "right"
  ) |>
  tidyr::pivot_longer(
    cols = dplyr::starts_with("sp"),
    names_to = "slot",
    values_to = "sp_code",
    values_drop_na = TRUE
  ) |>
  # !!!! here we are going to switch our CT to RB.  Reason for this is that we don't have information on assay for CT
  # seems unbc is saying that they can't differentiate but they didn't provide assay so we just use RB and go with that
  dplyr::mutate(sp_code = stringr::str_replace_all(sp_code, "CT", "RB")) |>
  dplyr::select(site_id, sp_code) |>
  dplyr::arrange(site_id, sp_code)

# simple map of species to assay options
assay_map <- assay_raw |>
  dplyr::mutate(
    # belt + suspenders: remove whitespace again
    assay_id    = stringr::str_remove_all(assay_id, "\\s"),
    dye_from_id = stringr::str_extract(assay_id, "(?<=-)[A-Z]+$"),
    assay_dye   = dplyr::coalesce(assay_dye, dye_from_id)
  ) |>
  dplyr::distinct(sp_code, assay_id, assay_dye, notes)

# join the sites to all assay options
assay_site_map <- site_species |>
  dplyr::left_join(
    assay_map,
    by = "sp_code"
  )|>
  dplyr::arrange(site_id, sp_code)

# # remove duplicates and understand how many runs for each species to enable efficient dye use
# site_dye_species_count <- assay_site_map |>
#   dplyr::distinct(site_id, sp_code, assay_dye) |>
#   dplyr::count(site_id, assay_dye, name = "n_species")
#
# # see how many dyes per site:
# site_dye_count <- assay_site_map |>
#   dplyr::distinct(site_id, assay_dye) |>
#   dplyr::count(site_id, name = "n_dyes")

## 1) Decide preferred dye per site (based on how many FAM vs VIC options exist)

# overall most common dye, for tie-breaks
dye_preferred <- assay_map |>
  dplyr::count(assay_dye, name = "n") |>
  dplyr::arrange(dplyr::desc(n)) |>
  dplyr::pull(assay_dye) |>
  dplyr::first()

#
site_pref <- assay_site_map |>
  dplyr::group_by(site_id) |>
  dplyr::summarise(
    n_fam = sum(assay_dye == "FAM", na.rm = TRUE),
    n_vic = sum(assay_dye == "VIC", na.rm = TRUE),
    .groups = "drop"
  ) |>
  dplyr::mutate(
    site_pref_dye = dplyr::case_when(
      n_fam >  n_vic ~ "FAM",
      n_vic >  n_fam ~ "VIC",
      TRUE          ~ dye_preferred  # tie / no info
    )
  )

## 2) For each site + species, keep ONE row:
##    if there are 2 dyes, keep the one that matches site_pref_dye

site_chosen <- assay_site_map |>
  dplyr::left_join(site_pref, by = "site_id") |>
  dplyr::group_by(site_id, sp_code) |>
  dplyr::arrange(
    site_id,
    sp_code,
    dplyr::desc(assay_dye == site_pref_dye)  # preferred dye first if it exists
  ) |>
  dplyr::slice(1) |>   # keep just one dye per site/species
  dplyr::ungroup() |>
  dplyr::select(site_id, sp_code, assay_id, assay_dye, notes)

## 3) Assign run_number so all same-dye species at a site share a number
##    (if all one dye → everything is run_number = 1)

site_ordered <- site_chosen |>
  dplyr::group_by(site_id) |>
  dplyr::mutate(
    n_fam = sum(assay_dye == "FAM", na.rm = TRUE),
    n_vic = sum(assay_dye == "VIC", na.rm = TRUE),
    dye_priority = dplyr::case_when(
      is.na(assay_dye) ~ 3L,
      n_fam >= n_vic & assay_dye == "FAM" ~ 1L,
      n_fam >= n_vic & assay_dye == "VIC" ~ 2L,
      n_vic >  n_fam & assay_dye == "VIC" ~ 1L,
      n_vic >  n_fam & assay_dye == "FAM" ~ 2L
    ),
    run_number = dye_priority
  ) |>
  dplyr::arrange(site_id, run_number, sp_code) |>
  dplyr::ungroup() |>
  dplyr::select(
    site_id,
    run_number,   # all same-dye rows at a site share this
    sp_code,
    assay_id,
    assay_dye,
    notes
  ) |>
  dplyr::group_by(site_id) |>
  dplyr::mutate(
    site_pattern = paste(sort(unique(assay_dye[order(run_number)])), collapse = ">"),
    run_order    = dplyr::row_number()
  ) |>
  dplyr::ungroup()

# define the pattern that the dyes will be run in order as
d_site_pattern <- site_ordered |>
  dplyr::group_by(site_id) |>
  dplyr::summarise(
    site_pattern = assay_dye[order(run_number, sp_code)] |>
      tolower() |>
      paste(collapse = "_"),
    .groups = "drop"
  ) |>
  dplyr::mutate(
    site_pattern_id = as.integer(factor(site_pattern))
  ) |>
  dplyr::arrange(site_pattern_id, site_id)

# finalize the plan that we are producing
site_plan <- site_ordered |>
  dplyr::group_by(site_id) |>
  dplyr::mutate(
    site_pattern = assay_dye[order(run_number, sp_code)] |>
      tolower() |>
      paste(collapse = "_"),
    run_order = dplyr::row_number()
  ) |>
  dplyr::ungroup() |>
  dplyr::mutate(
    site_pattern_id = as.integer(factor(site_pattern))
  ) |>
  dplyr::group_by(site_pattern_id, site_pattern) |>
  dplyr::arrange(site_id, .by_group = TRUE) |>
  dplyr::ungroup()


# ---- Post-processing: KO→SK, PK→BT, and lab group assignments ----

# Change KO to SK (same SOCK assay)
site_plan <- site_plan |>
  dplyr::mutate(sp_code = dplyr::if_else(sp_code == "KO", "SK", sp_code))

# For the PK sample (site 197960_ds_ed1), replace PK with BT to move to group 8
# per email discussion with Caitlin - dropping PK and subbing BT
site_plan <- site_plan |>
  dplyr::mutate(
    sp_code = dplyr::if_else(site_id == "197960_ds_ed1" & sp_code == "PK", "BT", sp_code),
    assay_id = dplyr::if_else(site_id == "197960_ds_ed1" & sp_code == "BT" & is.na(assay_id),
                               "BUT-VIC", assay_id),
    assay_dye = dplyr::if_else(site_id == "197960_ds_ed1" & sp_code == "BT" & is.na(assay_dye),
                                "VIC", assay_dye),
    notes = dplyr::if_else(site_id == "197960_ds_ed1" & sp_code == "BT",
                           "Also tests for DV but does not distinguish", notes)
  )

# Define Caitlin's group mappings based on species combinations
# Group 1: BB BT GR RB (2 samples)
# Group 2: CH CO DV SK (3 samples) - uses DV which also tests BT
# Group 3: CO DV RB SK (1 sample) - uses DV which also tests BT
# Group 4: BT CH (2 samples)
# Group 5: BT CH RB SK (5 samples)
# Group 6: CH CO RB SK (1 sample)
# Group 7: was CH CO PK SK - reassigned to group 8 with BT added
# Group 8: BT CH CO SK (9 samples, +1 from PK reassignment)
# Group 9: BB BT CH SK (1 sample)
# Group 10: BB BT CH RB (5 samples)
# Group 11: BT CH CO RB (26 samples)
# Group 12: BT RB (9 samples)
# Group 13: BT GR RB SK (27 samples) - was KO, now SK
# Group 14: BT CO RB (1 sample) - 197379_us_ed1, not in Caitlin's original groupings

# Get species combo per site and assign group
site_groups <- site_plan |>
  dplyr::group_by(site_id) |>
  dplyr::summarise(
    species_combo = paste(sort(unique(sp_code)), collapse = " "),
    .groups = "drop"
  ) |>
  dplyr::mutate(
    lab_group = dplyr::case_when(
      species_combo == "BB BT GR RB" ~ 1L,
      species_combo == "CH CO DV SK" ~ 2L,
      species_combo == "CO DV RB SK" ~ 3L,
      species_combo == "BT CH" ~ 4L,
      species_combo == "BT CH RB SK" ~ 5L,
      species_combo == "CH CO RB SK" ~ 6L,
      species_combo == "BT CH CO SK" ~ 8L,
      species_combo == "BB BT CH SK" ~ 9L,
      species_combo == "BB BT CH RB" ~ 10L,
      species_combo == "BT CH CO RB" ~ 11L,
      species_combo == "BT RB" ~ 12L,
      species_combo == "BT GR RB SK" ~ 13L,
      species_combo == "BT CO RB" ~ 14L,
      TRUE ~ NA_integer_
    )
  )

# Join group back to main data
site_plan <- site_plan |>
  dplyr::left_join(site_groups |> dplyr::select(site_id, lab_group), by = "site_id")

# Read UNBC run order mapping (based on Caitlin's Excel)
unbc_run_order <- readr::read_csv(
  "~/Projects/repo/dff-2022/data/edna_group_run_order.csv",
  show_col_types = FALSE
)

# Add run_order_unbc and sheet_name_unbc, arrange by UNBC's order
site_plan <- site_plan |>
  dplyr::left_join(unbc_run_order, by = c("lab_group", "sp_code")) |>
  dplyr::arrange(lab_group, site_id, run_order_unbc)

# Join region and source from d_raw
site_region_lookup <- d_raw |>
  dplyr::distinct(site_id, region, source)

site_plan <- site_plan |>
  dplyr::left_join(site_region_lookup, by = "site_id")

# Generate id_lab: region + site_pattern_id + lab_group + row_number
# Sort by region, lab_group, site_id first to get consistent row numbers
site_plan <- site_plan |>
  dplyr::arrange(region, lab_group, site_id, run_order_unbc)

# Create pivot-wide version for lab (one row per site_id)
# with id_lab = region + site_pattern_id + lab_group + row_number
site_plan_wide <- site_plan |>
  dplyr::group_by(site_id) |>
  dplyr::summarise(
    region = dplyr::first(region),
    site_pattern_id = dplyr::first(site_pattern_id),
    lab_group = dplyr::first(lab_group),
    sheet_name_unbc = dplyr::first(sheet_name_unbc),
    site_pattern = dplyr::first(site_pattern),
    sp_code1 = sp_code[1],
    sp_code2 = sp_code[2],
    sp_code3 = sp_code[3],
    sp_code4 = sp_code[4],
    .groups = "drop"
  ) |>
  # Sort by region, lab_group, site_id for row numbering
  dplyr::arrange(region, lab_group, site_id) |>
  # Add row number (actual spreadsheet row, 1-indexed)
  dplyr::mutate(
    row_num = dplyr::row_number(),
    # id_lab = region + site_pattern_id + lab_group (2-digit) + row (2-digit)
    id_lab = paste0(
      region,
      site_pattern_id,
      sprintf("%02d", lab_group),
      sprintf("%02d", row_num)
    )
  )

# Master reference with all id_lab components for decoding when samples return
site_plan_master <- site_plan_wide |>
  dplyr::select(
    id_lab, row_num, region, site_pattern_id, lab_group,
    site_id, sheet_name_unbc, sp_code1, sp_code2, sp_code3, sp_code4, site_pattern
  )

# Simplified version for lab (fewer columns)
site_plan_wide <- site_plan_wide |>
  dplyr::select(
    id_lab, site_id, sheet_name_unbc, lab_group,
    sp_code1, sp_code2, sp_code3, sp_code4, site_pattern
  )

# Also add id_lab back to the long-form site_plan for reference
id_lab_lookup <- site_plan_wide |>
  dplyr::select(site_id, id_lab)

site_plan <- site_plan |>
  dplyr::left_join(id_lab_lookup, by = "site_id") |>
  dplyr::relocate(id_lab, .after = site_id) |>
  dplyr::relocate(region, source, .after = id_lab)

# Summary of groups for verification
cat("\n=== Lab Group Summary ===\n")
group_summary <- site_plan |>
  dplyr::group_by(lab_group, sheet_name_unbc) |>
  dplyr::summarise(
    n_samples = dplyr::n_distinct(site_id),
    .groups = "drop"
  )
print(group_summary, n = 20)

# Export to edna_unbc/ directory for m1rr0r sync (one row per site_id with id_lab)
# Use date suffix for versioning
date_suffix <- format(Sys.Date(), "%Y%m%d")
output_dir <- "~/Projects/repo/fish_passage_template_reporting/data/backup/2025/edna_unbc"
fs::dir_create(output_dir)

# CSV - wide format with sp_code1-4
path_csv <- file.path(output_dir, paste0("edna_for_UNBC_", date_suffix, ".csv"))
site_plan_wide |>
  readr::write_excel_csv(path_csv)
cat("\nCSV saved to", path_csv, "\n")

# Excel - wide format with grouped sheets
wb <- openxlsx::createWorkbook()

# Sheet 1: All data (wide format)
openxlsx::addWorksheet(wb, "all_samples")
openxlsx::writeData(wb, "all_samples", site_plan_wide)

# Add a sheet for each lab_group (wide format)
for (i in seq_len(nrow(group_summary))) {
  grp <- group_summary$lab_group[i]
  sheet_name <- group_summary$sheet_name_unbc[i]
  grp_data <- site_plan_wide |> dplyr::filter(lab_group == grp)
  openxlsx::addWorksheet(wb, sheet_name)
  openxlsx::writeData(wb, sheet_name, grp_data)
}

path_xlsx <- file.path(output_dir, paste0("edna_for_UNBC_", date_suffix, ".xlsx"))
openxlsx::saveWorkbook(wb, path_xlsx, overwrite = TRUE)
cat("Excel saved to", path_xlsx, "\n")

# Save master reference sheet (with all id_lab components) OUTSIDE edna_unbc/
# This is for internal use to decode samples when results return - not for lab
master_dir <- "~/Projects/repo/fish_passage_template_reporting/data/backup/2025"
path_master_csv <- file.path(master_dir, paste0("edna_id_lab_master_", date_suffix, ".csv"))
site_plan_master |>
  readr::write_excel_csv(path_master_csv)
cat("Master reference CSV saved to", path_master_csv, "\n")

# Also add master as a sheet in the lab Excel for convenience
openxlsx::addWorksheet(wb, "id_lab_reference")
openxlsx::writeData(wb, "id_lab_reference", site_plan_master)
openxlsx::saveWorkbook(wb, path_xlsx, overwrite = TRUE)
cat("Added id_lab_reference sheet to Excel\n")

# Print sample of id_lab values for QA
cat("\n=== Sample id_lab values ===\n")
site_plan_wide |>
  dplyr::select(id_lab, site_id, sheet_name_unbc, sp_code1, sp_code2) |>
  print(n = 15)

