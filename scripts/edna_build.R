#'  build a raw field form template using the excel file as the template for our template

# source('scripts/packages.R')

# path_write <- 'data/qgis/form_pscis.gpkg'
path_write <- 'data/qgis/form_edna.gpkg'
layer_name <- "form_edna"
path_template <- "data/templates/template_edna.xlsx"


# whole thing is now a function
ldff_edna_build <- function(path){

  #' name the project directory we are burning to
  # dir_project <- 'bcfishpass_20230517'

  #' name the form using the date and time
  #' we should be able to name the form the same in the active project but the files can be versioned
  #' seems safer...
  # file_name <- paste0('form_fiss_site_', format(lubridate::now(), "%Y%m%d"))


  #' import the fish data submission template (needs to be in the data directory)
  #' because we want to keep the backup file clean for the value maps and because
  #' we are not worried about version controling this data we turn the `backup` function to `FALSE`

  fpr::fpr_import_hab_con(path = path_template,
                                      backup = F,
                                      row_empty_remove = F
                                      ) |>
    # pull out just the template
    purrr::pluck(1) |>
    # if the column name contains date then convert to datetime
    dplyr::mutate(
      dplyr::across(
        dplyr::contains("date"),
        ~ lubridate::as_datetime(.x, tz = "America/Vancouver")
      )
    ) |>
    fpr::fpr_sp_assign_sf_from_utm(
      col_easting = "utm_easting",
      col_northing = "utm_northing"
    ) |>
    sf::st_write(
      path,
      delete_layer = T,
      layer = layer_name)
}

# run the function
ldff_edna_build(path_write)



