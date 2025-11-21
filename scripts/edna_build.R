#'  build a raw field form template using the excel file as the template for our template

# path_write <- 'data/qgis/form_pscis.gpkg'
path_write <- 'data/qgis/form_edna.gpkg'
layer_name <- "form_edna"
path_template <- "data/templates/template_edna.xlsx"


# whole thing is now a function
ldff_edna_build <- function(path){

  t <- fpr::fpr_import_hab_con(path = path_template,
                                      backup = T,
                                      row_empty_remove = F
                                      ) |>
    # pull out just the template
    purrr::pluck(1) |>
    # if the column name contains date then convert to datetime
    dplyr::mutate(
      dplyr::across(
        dplyr::contains("time"),
        ~ lubridate::as_datetime(.x, tz = "America/Vancouver")
      )
    ) |>
    fpr::fpr_sp_assign_sf_from_utm(
      col_easting = "utm_easting",
      col_northing = "utm_northing"
    ) |>
    # filter_time is numeric so
    dplyr::mutate(
      filter_time = as.numeric(filter_time)
    )

  t |>
    sf::st_write(
      path,
      delete_layer = T,
      layer = layer_name)
}

# run the function
ldff_edna_build(path_write)



