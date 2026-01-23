#!/bin/bash
set -euxo pipefail

# Name of the target location
TARGET="background_layers.gpkg"

# Check that watershed group code is provided as an argument
if [ $# -eq 0 ]; then
    echo "No arguments supplied - provide list of watershed_group_code values for watersheds of interest."
    exit 1
fi

# Function to check the format of the argument and provide proper feedback
# https://chatgpt.com/share/f73eac46-032e-47b5-86ec-e9d711f36ff1
check_format() {
  local input="$1"

  # Check if the input format is correct
  if [[ ! $input =~ ^\'[^\']+\'(,\ *\'[^\']+\')*$ ]]; then
    echo "Invalid format for watershed groups supplied."
    echo "You provided: \"$input\""
    echo "Please provide the names in the format: \"'BULK'\" or \"'BULK', 'KLUM'\" with single quotes around each name and optionally separated by commas."
    exit 1
  fi
}

# Check that the watershed groups are in the correct format
check_format "$1"

echo "Watershed groups format is correct: $1"

# Temporarily disable the nounset option to allow for default values if one is not set
set +u

# Assign a default value to $2 if it's not set
operation=${2:-"generate"}

# Re-enable the nounset option
set -u


# Check for "update" flag and existence of the GeoPackage file
if [[ "$operation" == "update" && ! -f "$TARGET" ]]; then
    echo "$TARGET does not exist. Cannot perform update operation."
    exit 1
fi


process_geopackage() {
    local watersheds="$1"
    local operation="${2-}" # Default to empty if not set

    echo "Processing watershed group boundaries: $watersheds"
    rm -f aoi.geojson
    bcdata dump WHSE_BASEMAPPING.FWA_WATERSHED_GROUPS_POLY \
        --query "WATERSHED_GROUP_CODE in ($watersheds)" -l > aoi.geojson

    local update_option=""
    if [[ "$operation" == "update" ]]; then
        update_option="-update"
    fi

    ogr2ogr -f GPKG "$TARGET" \
            $update_option \
            -overwrite \
            -t_srs EPSG:3005 \
            -nln whse_basemapping.fwa_watershed_groups_poly \
            aoi.geojson
}

# Main script logic
if [[ -f "$TARGET" ]]; then
    # Always update if file exists (assume update mode)
    echo "Updating existing $TARGET with area of interest..."
    process_geopackage "$1" "update"
else
    if [[ "$operation" == "update" ]]; then
        # This block should never be reached due to the initial check, but it's here for logical completeness
        echo "Cannot perform update because $TARGET is missing."
        exit 1
    else
        echo "Generating a new one..."
        process_geopackage "$1"
    fi
fi



# get bounding box of project area in BC Albers and WGS84 (lon/lat)
BOUNDS=$(fio info background_layers.gpkg --layer whse_basemapping.fwa_watershed_groups_poly --bounds)
BOUNDS_LL=$(echo "[$BOUNDS]" | tr ' ', ',' | rio transform --src_crs EPSG:3005 --dst_crs EPSG:4326 | tr -d '[] ')

# name the sources file
SOURCES_RAW="rfp_source_fwa.txt"

# don't grab hashed out entries or empty lines
SOURCES=$(grep -vE '^\s*#|^\s*$' "$SOURCES_RAW")

echo 'Getting layers from https://features.hillcrestgeo.ca/fwa/collections- this may take a while'

for layer in $SOURCES; do
    ogr2ogr -f GPKG "$TARGET" \
        -update \
        -overwrite \
        -t_srs EPSG:3005 \
        -nln "$layer" \
        -clipsrc aoi.geojson \
        -clipsrclayer aoi \
        "https://features.hillcrestgeo.ca/fwa/collections/$layer/items.json?bbox=$BOUNDS_LL"
done
