# make map of site vs species ordered by the assay dye order to send to UNBC

# read iin edna form
d_raw <- readr::read_csv(
  "~/Projects/repo/fish_passage_template_reporting/data/backup/2025/form_edna_2025.csv"
) |>
  dplyr::select(
    site_id,
    # date_time_sample,
    species_target
    # makes it easier to see where manual changes are helpful
    # source
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
      stringr::str_to_upper()
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

# Summary of groups for verification
cat("\n=== Lab Group Summary ===\n")
group_summary <- site_plan |>
  dplyr::group_by(lab_group, sheet_name_unbc) |>
  dplyr::summarise(
    n_samples = dplyr::n_distinct(site_id),
    .groups = "drop"
  )
print(group_summary, n = 20)

# burn csv to the repo so we can point the lab to it
path <- "~/Projects/repo/fish_passage_template_reporting/data/backup/2025/edna_species_for_UNBC.csv"
fs::dir_create(fs::path_dir(path))
site_plan |>
  readr::write_excel_csv(path)

# Export to Excel with each group as a separate sheet (using UNBC's naming)
wb <- openxlsx::createWorkbook()

# Sheet 1: All data
openxlsx::addWorksheet(wb, "edna_species_for_UNBC")
openxlsx::writeData(wb, "edna_species_for_UNBC", site_plan)

# Add a sheet for each group, named per UNBC convention
for (i in seq_len(nrow(group_summary))) {
  grp <- group_summary$lab_group[i]
  sheet_name <- group_summary$sheet_name_unbc[i]
  grp_data <- site_plan |> dplyr::filter(lab_group == grp)
  openxlsx::addWorksheet(wb, sheet_name)
  openxlsx::writeData(wb, sheet_name, grp_data)
}

path_xlsx <- "~/Projects/repo/fish_passage_template_reporting/data/backup/2025/edna_species_for_UNBC_grouped.xlsx"
openxlsx::saveWorkbook(wb, path_xlsx, overwrite = TRUE)
cat("\nExcel file saved to", path_xlsx, "\n")

