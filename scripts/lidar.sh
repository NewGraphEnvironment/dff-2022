#!/bin/bash

set -euxo pipefail

# start the timer
SECONDS=0

mkdir -p data/lidar

wget --trust-server-names -qN https://nrs.objectstore.gov.bc.ca/gdwuts/093/093l/2019/dem/bc_093l056_xli1m_utm09_2019.tif --directory-prefix=data/lidar

# convert to cog
rio cogeo create data/lidar/bc_093l056_xli1m_utm09_2019.tif data/lidar/bc_093l056_xli1m_utm09_2019_cog.tif

echo 'This took' \
$SECONDS \
echo 'seconds'