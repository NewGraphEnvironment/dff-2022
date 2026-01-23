#!/bin/bash
set -euxo pipefail

# ---------------
# extract layers from aws to load to background_layers.gpkg within digital field projects

# usage: specify watershed groups of interest as a comma separated, single quoted string
# eg
# test with ./rfp_sources_aws.sh "'PARS'" &>log.txt
# ---------------


# check that watershed group code is provided as argument
if [ $# -eq 0 ]
  then
    echo "No arguments supplied - provide list of watershed_group_code values for watersheds of interest"
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


# Name of the file
GPKG="background_layers.gpkg"

# name the sources file
SOURCES="rfp_source_aws.txt"

# Check if the GPKG IS NOT there
if [[ ! -f $GPKG ]]; then
  # If the file exists, ask the user if they wish to remove it
  echo "There should already be a file called $GPKG. Please provide."
  exit 1
else
echo 'Updateing project area from watershed group boundaries: '$1
    rm -f aoi.geojson
    bcdata dump WHSE_BASEMAPPING.FWA_WATERSHED_GROUPS_POLY \
        --query "WATERSHED_GROUP_CODE in ($1)" -l > aoi.geojson
        ogr2ogr -f GPKG background_layers.gpkg \
            -update \
            -overwrite \
            -t_srs EPSG:3005 \
            -nln whse_basemapping.fwa_watershed_groups_poly \
            aoi.geojson
fi

# get bounding box of project area in BC Albers and WGS84 (lon/lat)
BOUNDS=$(fio info background_layers.gpkg --layer whse_basemapping.fwa_watershed_groups_poly --bounds)
BOUNDS_LL=$(echo "[$BOUNDS]" | tr ' ', ',' | rio transform --src_crs EPSG:3005 --dst_crs EPSG:4326 | tr -d '[] ')


# ---------------
# lateral habitat
# ---------------
# should be able to pipe $(fio cat aoi.geojson --dst_crs EPSG:3005) to rio mask for a one liner,
# but this works fine

echo 'Clipping lateral habitat tiff to project area'
ogr2ogr -f GeoJSON aoi_alb.geojson -t_srs EPSG:3005 aoi.geojson

rio mask /vsicurl/https://newgraph.s3.us-west-2.amazonaws.com/habitat_lateral.tif \
  habitat_lateral.tif \
  --overwrite \
  --crop \
  --geojson-mask aoi_alb.geojson

rm aoi_alb.geojson

# ---------------
# bcfishpass releated data sources archived to flatgeobuf on s3 for fast retrieval
# (and with watershed group code included, no spatial query for clipping required)
# ---------------
echo 'Getting bcfishpass and supporting layers from s3'

# get a list of the aws layers to update
FGB_SOURCES=$(grep -v '^#' $SOURCES)

# Create temp directory for downloads
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

for layer in $FGB_SOURCES; do
  echo "Processing $layer..."

  # Download and unzip to temp
  wget -q -O "$TMPDIR/${layer}.fgb.zip" \
    "https://newgraph.s3.us-west-2.amazonaws.com/${layer}.fgb.zip"
  unzip -q -o "$TMPDIR/${layer}.fgb.zip" -d "$TMPDIR"

  # Process locally (much faster)
  ogr2ogr \
    -f GPKG background_layers.gpkg \
    -update \
    -overwrite \
    -nln $layer \
    -t_srs EPSG:3005 \
    -dim XY \
    -spat $BOUNDS \
    -spat_srs EPSG:3005 \
    -where "watershed_group_code in ($1)" \
    "$TMPDIR/${layer}.fgb" \
    $layer

  # Clean up this layer's files
  rm -f "$TMPDIR/${layer}.fgb.zip" "$TMPDIR/${layer}.fgb"
done

# ---------------
# model parameters
# ---------------
echo 'Getting model parameter info from aws'

# update the model info used to create the crossings and streams layers
CSVS=("parameters_habitat_method" "parameters_habitat_thresholds")

for layer in "${CSVS[@]}"; do
  ogr2ogr \
    -f GPKG background_layers.gpkg \
    -update \
    -overwrite \
    -nln $layer \
    /vsicurl/https://newgraph.s3.us-west-2.amazonaws.com/$layer.csv
done

# ---------------
# named streams
# ---------------
echo 'Getting named streams from fwapg feature service'
ogr2ogr -f GPKG background_layers.gpkg \
    -update \
    -overwrite \
    -t_srs EPSG:3005 \
    -nln whse_basemapping.fwa_named_streams \
    -clipsrc aoi.geojson \
    -clipsrclayer aoi \
    "https://features.hillcrestgeo.ca/fwa/collections/whse_basemapping.fwa_named_streams/items.json?bbox=$BOUNDS_LL"
    # "http://www.a11s.one:9000/collections/whse_basemapping.fwa_named_streams/items.json?bbox=$BOUNDS_LL"

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

echo 'layers stored on aws are now loaded to background_layers.gpkg'





