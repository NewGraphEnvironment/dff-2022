source('scripts/packages.R')

# import a geopackage and rearrange then burn to csv

# relative path to the q project form (assuming we havre same folder structure) -
# use an absolute path if you have to but it is preferable to keep our relative paths the same so we can collab

# name the project directory we are pulling from
dir_project <- 'bcfishpass_skeena_20220823'

# list all the fiss form names in the file
form_names_l <- list.files(path = paste0('../../gis/mergin/',
                                         dir_project),
                           # ?glob2rx is a funky little unit
                           pattern = glob2rx('*site_2022*.gpkg'),
                           full.names = T
)

# read all the forms into a list of dataframes using colwise to guess the column types
# if we don't try to guess the col types we have issues later with the bind_rows join
form <- form_names_l %>%
  purrr::map(sf::st_read) %>%
  purrr::map(plyr::colwise(type.convert)) %>%
  # name the data.frames so we can add it later as a "source" column - we use basename to leave the filepath behind
  purrr::set_names(nm = basename(form_names_l)) %>%
  bind_rows(.id = 'source')

# see the names of our form
names(form)

# we just want to filter the rows that have a second feature and/or a third feature in them,
# because there is no column for these in the habitat confirmation template, we have to add them as separate entries
# I've also added feature 1 to the final output just in case, because I remember there being a bug in the forms at one point where
# you couldn't add LWD in feature_type_1 field so we had to add it as text to a feature_2 field, this issue has since been patched

form_features <- form %>%
  filter(!is.na(feature_type_2)) %>%
  select(gazetted_names, local_name, gps_id, starts_with("feature")) %>%
  group_by(local_name)

#view(form_features)

# burn to file

form_features %>%
  readr::write_csv(paste0(
    'data/skeena/form_fiss_features_',
    format(lubridate::now(), "%Y%m%d"),
    '.csv'),
    na = '')



