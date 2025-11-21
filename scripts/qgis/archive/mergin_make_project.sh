#!/bin/bash
set -euxo pipefail

# 20241003 run in dff2 virtual environment

# sern_fraser_2024
# ./rfp_source_bcdata.sh "'LCHL', 'NECR', 'FRAN', 'MORK', 'UFRA', 'TABR', 'WILL'" && ./rfp_source_aws.sh "'LCHL', 'NECR', 'FRAN', 'MORK', 'UFRA', 'TABR', 'WILL'" && time ./rfp_qgis_create.sh "sern_fraser_2024" "bcrestoration_mobile.qgs"

# ---------------
# create project
# ---------------
# with Mergin Maps authentication token string set as --auth-token env variable run
mergin create newgraph/sern_fraser_2024 --from-dir ~/Projects/gis/sern_fraser_2024

# ---------------
# invite collaborators
# ---------------
# executed from project directory with .mergin file present
mergin share-add newgraph/sern_fraser_2024 newgraph_bute --permissions writer /
mergin share-add newgraph/sern_fraser_2024 newgraph_lschick --permissions writer /
mergin share-add newgraph/sern_fraser_2024 snorris --permissions writer /
mergin share-add newgraph/sern_fraser_2024 seanwong --permissions writer /
mergin share-add newgraph/sern_fraser_2024 sern_bgeldart --permissions writer /
mergin share-add newgraph/sern_fraser_2024 jmdegagn --permissions writer /
mergin share-add newgraph/sern_fraser_2024 Alexandras --permissions writer /
mergin share-add newgraph/sern_fraser_2024 tdonald --permissions writer /
mergin share-add newgraph/sern_fraser_2024 rivershed_jmarquis --permissions writer

#mya may need quote in name to get over the space....
# mergin share-add newgraph/sern_fraser_2024 Mya Eastmure --permissions writer
# ---------------
# sync changes
# ---------------
# executed from project directory with .mergin file present
# mergin status newgraph/sern_fraser_2024
# mergin push newgraph/sern_fraser_2024

# ---------------
# clone a project
# ---------------
