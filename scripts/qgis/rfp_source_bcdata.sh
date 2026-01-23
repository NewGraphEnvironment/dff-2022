#!/bin/bash
set -euxo pipefail


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



# clean out the old files
rm -f *.geojson

# Name of the GeoPackage file
GPKG="background_layers.gpkg"

# name the sources file
SOURCES="rfp_source_bcdata.txt"


# Check for "update" flag and existence of the GeoPackage file
if [[ "$operation" == "update" && ! -f "$GPKG" ]]; then
    echo "$GPKG does not exist. Cannot perform update operation."
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

    ogr2ogr -f GPKG "$GPKG" \
            $update_option \
            -overwrite \
            -t_srs EPSG:3005 \
            -nln whse_basemapping.fwa_watershed_groups_poly \
            aoi.geojson
}

# Main script logic
if [[ -f "$GPKG" ]]; then
    if [[ "$operation" == "update" ]]; then
        echo "Updating existing $GPKG with area of interest..."
        process_geopackage "$1" "update"
    else
        read -p "Do you wish to start over with a new $GPKG? If you are updating existing project info say NO (y/n): " answer
        if [[ $answer == "y" ]]; then
            echo "Removing $GPKG..."
            rm -f "$GPKG"
            process_geopackage "$1"
        else
            echo "Updating existing $GPKG with area of interest..."
            process_geopackage "$1" "update"
        fi
    fi
else
    if [[ "$operation" == "update" ]]; then
        # This block should never be reached due to the initial check, but it's here for logical completeness
        echo "Cannot perform update because $GPKG is missing."
        exit 1
    else
        echo "Generating a new one..."
        process_geopackage "$1"
    fi
fi


# get bounding box of aoi in BC Albers and WGS84 (lon/lat)
BOUNDS=$(fio info aoi.geojson --layer aoi --bounds)
BOUNDS_LL=$(echo "[$BOUNDS]" | tr ' ', ',' | rio transform --src_crs EPSG:3005 --dst_crs EPSG:4326 | tr -d '[] ')


# ---------------
# non-fwa bcgw layers
# ---------------
echo 'Getting BC Data Catalogue layers - this may take a while'
BCGW_SOURCES=$(grep -v '^#' $SOURCES)
for layer in $BCGW_SOURCES; do
    if [ ! -f ./$layer.geojson ]; then
        set -e ; bcdata dump $layer --bounds "$BOUNDS" --bounds-crs EPSG:3005 -l > $layer.geojson
    fi
done

# remove empty fwa tables created by bcdata because sql query will fail later
find . -maxdepth 1 -type f -name "*.fwa_*" -size -50c -delete


# get the name of the files (except aoi.geojson) that are left after tiny ones are removed
BCGW_SOURCES_CLEANED=$(find . -maxdepth 1 -type f -name "*.geojson" -a '!' -name "aoi.geojson" -exec basename {} .geojson \;)


for layer in $BCGW_SOURCES_CLEANED; do
    if [[ $layer == *".fwa_"* ]]; then
        ogr2ogr -f GPKG \
            background_layers.gpkg \
            -update \
            -overwrite \
            -t_srs EPSG:3005 \
            -nln $layer \
            -dim XY \
            -where "watershed_group_code in ($1)" \
            $layer.geojson
    else
        ogr2ogr -f GPKG \
            background_layers.gpkg \
            -update \
            -overwrite \
            -t_srs EPSG:3005 \
            -nln $layer \
            -dim XY \
            -clipsrc aoi.geojson \
            -clipsrclayer aoi \
            $layer.geojson
    fi
done

echo 'Creating a record of the layers that were loaded'
# create a record of the layers that were loaded
# Get the current date and time
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')

# should remove this header now but will remove with script for now instead
# Header for the CSV file
# echo "timestamp,content,watershed_groups,source" > temp.csv

# Use awk to process the text file line by line - remove the commas from the watershed_groups variable
awk -v timestamp="$TIMESTAMP" -v watershed_groups="$1" -v source="$SOURCES" 'BEGIN{gsub(",", "", watershed_groups)} !/^#/ && NF > 0 {print timestamp "," $0 "," watershed_groups "," source}' $SOURCES > temp.csv

# -----------------get the descriptions from the bcdata catalogue preprocessed with rfp_lookup_bcdata.sh

# Sort temp.csv based on the second column and rfp_list_bcdata.csv based on the first column, excluding the header row
# tail -n +2 temp.csv | sort -t, -k2,2 > temp_sorted.csv


# Sort temp.csv based on the second column and rfp_lookup_bcdata.csv based on the first column
sort -t, -k2,2 temp.csv > temp_sorted.csv
tail -n +2 rfp_lookup_bcdata.csv | sort -t, -k1,1 > rfp_lookup_bcdata_sorted.csv

# Write the header row to output.csv
echo "timestamp,content,watershed_groups,source,description" > output.csv

# Join the files on the schema_table column and print all columns from temp.csv and the description column from rfp_lookup_sorted.csv
join -t, -1 2 -2 1 -a 1 -o 1.1,1.2,1.3,1.4,2.2 temp_sorted.csv rfp_lookup_bcdata_sorted.csv >> output.csv

# Append the temporary CSV file to the GeoPackage
ogr2ogr -append -f "GPKG" $GPKG output.csv -nln rfp_tracking

# Remove the temporary CSV files
rm temp.csv temp_sorted.csv rfp_lookup_bcdata_sorted.csv output.csv

echo 'bcdata layers are now loaded to background_layers.gpkg'


