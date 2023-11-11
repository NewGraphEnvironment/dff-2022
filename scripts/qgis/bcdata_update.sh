#!/bin/bash
set -euxo pipefail

# this script assumes the background_layers.gpkg is in the scripts/qgis directory... maybe a bit dangerous


# check that watershed group code is provided as argument
if [ $# -eq 0 ]
  then
    echo "No arguments supplied - provide list of watershed_group_code values for watersheds of interest"
    exit 1
fi

# generate aoi
rm -f aoi.geojson
bcdata dump WHSE_BASEMAPPING.FWA_WATERSHED_GROUPS_POLY \
    --query "WATERSHED_GROUP_CODE in ($1)" -l > aoi.geojson

# get bounding box of aoi in BC Albers and WGS84 (lon/lat)
BOUNDS_LL=$(fio info aoi.geojson --layer aoi --bounds)
BOUNDS=$(echo "[$BOUNDS_LL]" | tr ' ', ',' | rio transform --src_crs EPSG:4326 --dst_crs EPSG:3005 | tr -d '[] ')


# ---------------
# non-fwa bcgw layers
# ---------------
echo 'Getting BC Data Catalogue layers - this may take a while'
BCGW_SOURCES=$(cat bcdata_update.txt)
for layer in $BCGW_SOURCES; do
    if [ ! -f ./$layer.geojson ]; then
        set -e ; bcdata dump $layer --bounds "$BOUNDS" --bounds-crs EPSG:3005 -l > $layer.geojson
    fi
done

# load to gpkg
# ---------------
BCGW_SOURCES=$(cat bcdata_update.txt)
for layer in $BCGW_SOURCES; do
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

