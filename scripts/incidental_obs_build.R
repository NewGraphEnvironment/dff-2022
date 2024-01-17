# Build digital form for incidental observations, using submission template from bc gov

# "Incidental observations are casual sightings that happen when you’re outside - hiking, camping, swimming, driving, in your backyard, etc."
# Used to report info about healthy wild animals, fish and plants, sick, injured or dead animals

source('scripts/packages.R')

#' name the project directory we are burning to
dir_project <- 'bcfishpass_20230516'

#' name the form using the date and time
#' we should be able to name the form the same in the active project but the files can be versioned
file_name <- paste0('form_incid_obs_', format(lubridate::now(), "%Y%m%d"))

#' define your utm zone.  This can cause errors if you use the form in more than
#' one zone!!!!! beware
#' will set to Nelson utm for now, most observations will probably originate from here I suspect
utm_zone <- 11

#' import the incidental observations submission template (needs to be in the data directory)
#' because we want to keep the backup file clean for the value maps and because
#' we are not worried about version controlling this data we turn the `backup` function to `FALSE`

form_raw <- readxl::read_xlsx('data/incidental_observations.xlsm') %>%
  janitor::clean_names()

# see the names of the columns
names(form_raw)

incid_obs <- form_raw %>%
  # add link to methods that includes field descriptions
  mutate(methods = NA_character_) %>%
  # populate utm fields with a location so we can use to burn geopackage
  mutate(easting = 687879,
         northing = 6020659) %>%
  # make it a spatial file so we can burn it as a geopackage right into our mergin file of choice
  sf::st_as_sf(coords = c("easting", "northing"),
               crs = 32600 + utm_zone, remove = F) %>%
  # put it into albers so we can use it anywhere
  sf::st_transform(crs = 3005) %>%
  # burn to test project for now, will burn to dff when finalised
  sf::st_write(paste0('../../gis/',
                      dir_project,
                      '/other_forms/',
                      file_name,
                      '.gpkg'),
               # turned this T now that we have time in name
               delete_layer = T)
