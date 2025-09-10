# add metadata table to geopackage

path_write <- 'data/qgis/form_edna.gpkg'
path_template <- "data/templates/template_edna.xlsx"

# read your definitions
defs <- readxl::read_excel(path_template, sheet = "edna_definitions")

con <- DBI::dbConnect(RSQLite::SQLite(), path_write)

DBI::dbExecute(con, "
CREATE TABLE IF NOT EXISTS gpkg_data_columns (
  table_name TEXT NOT NULL,
  column_name TEXT NOT NULL,
  name TEXT,
  title TEXT,
  description TEXT,
  mime_type TEXT,
  constraint_name TEXT,
  PRIMARY KEY (table_name, column_name)
)")

DBI::dbExecute(con, "DELETE FROM gpkg_data_columns WHERE table_name = ?",
               params = list(layer_name))

sql <- "INSERT OR REPLACE INTO gpkg_data_columns
        (table_name, column_name, name, description)
        VALUES (?, ?, ?, ?)"

purrr::pwalk(
  list(defs$table_name, defs$column_name, defs$name, defs$description),
  ~ DBI::dbExecute(con, sql, params = list(..1, ..2, ..3, ..4))
)

DBI::dbDisconnect(con)
