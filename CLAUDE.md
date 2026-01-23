# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository creates digital field forms and QGIS projects for fish passage assessment, habitat assessment, and stream crossing climate change/maintenance risk assessment in British Columbia. The forms integrate with Mergin Maps for mobile field data collection on iOS and Android devices.

## Key Components

### Digital Field Forms (R Scripts)
R scripts in `scripts/` build geopackage-based field forms from provincial submission templates:
- **PSCIS forms**: `pscis_build_form.R` - Fish Passage stream crossing assessment
- **FISS Site forms**: `fiss_site_build_form.R` - Fish habitat site data
- **Fish Sample forms**: `fish_sample_build.R` - Fish sampling data
- **FHAP forms**: `fhap_build.R` - Fish habitat assessment
- **eDNA forms**: `edna_build.R` - Environmental DNA sampling
- **Monitoring forms**: `monitoring_build_form.R` - Restoration monitoring

Forms are written as `.gpkg` files to QGIS project directories (typically `~/Projects/gis/{project_name}/`).

### QGIS Project Creation (Shell Scripts)
Scripts in `scripts/qgis/` download BC government spatial data and create QGIS projects:

**Environment setup** (run from `scripts/qgis/`):
```bash
conda env create -f environment.yml
conda activate dff
```

**Data download scripts** - all take watershed group codes as argument:
```bash
# Download from BC Data Catalogue (bcdata/WFS)
time ./rfp_source_bcdata.sh "'BULK', 'KLUM'"

# Download from Freshwater Atlas API
time ./rfp_source_fwa.sh "'BULK', 'MORR'"

# Download from AWS (bcfishpass, habitat rasters)
time ./rfp_source_aws.sh "'BULK', 'KLUM'"
```

**Create new QGIS project**:
```bash
# Args: project_directory_name, qgis_template_file
time ./rfp_qgis_create.sh "project_name" "bcrestoration_mobile.qgs"
```

**Full workflow** (creates new project with all data):
```bash
time ./rfp_source_bcdata.sh "'BULK', 'KLUM'" && \
time ./rfp_source_aws.sh "'BULK', 'KLUM'" && \
time ./rfp_source_fwa.sh "'BULK', 'KLUM'" && \
time ./rfp_qgis_create.sh "project_name" "bcrestoration_mobile.qgs"
```

**Update existing project**:
```bash
# Copy gpkg from existing project to scripts/qgis/
cp ~/Projects/gis/existing_project/background_layers.gpkg ~/Projects/repo/dff-2022/scripts/qgis/

# Run update with "update" flag
time ./rfp_source_bcdata.sh "'BULK', 'KLUM'" "update"
time ./rfp_source_aws.sh "'BULK', 'KLUM'"

# Copy back
mv ~/Projects/repo/dff-2022/scripts/qgis/background_layers.gpkg ~/Projects/gis/existing_project/
```

## Important Paths

- **QGIS templates**: `data/qgis/bcfishpass_mobile.qgs`, `data/qgis/bcrestoration_mobile.qgs`
- **Form styling**: `data/qgis/*.qml` files
- **Form templates**: `data/qgis/form_*.gpkg`
- **Provincial templates**: `data/FDS_Template2021-01-28.xls`, `data/pscis_assessment_template_v24.xlsm`
- **Layer lists**: `scripts/qgis/rfp_source_bcdata.txt`, `scripts/qgis/rfp_source_fwa.txt`

## R Dependencies

Key R packages: `tidyverse`, `sf`, `fpr` (NewGraphEnvironment package), `readxl`, `bcdata`, `RPostgres`, `DBI`

Load packages via `source('scripts/packages.R')`.

The `fpr` package provides functions like `fpr_import_pscis_all()` and `fpr_import_hab_con()` for importing provincial templates.

## Python/Conda Environments

Two conda environments:
- `dff2` (root `environment.yml`): mergin-client, bcdata - for Mergin Maps sync
- `dff` (`scripts/qgis/environment.yml`): bcdata, geopandas, rasterio - for QGIS project creation

## Output Structure

Created QGIS projects go to `~/Projects/gis/{project_name}/` containing:
- `background_layers.gpkg` - BC government spatial layers clipped to watershed groups
- `habitat_lateral.tif` - Habitat raster
- `form_pscis.gpkg`, `form_fiss_site.gpkg` - Field form layers
- `{project_name}.qgs` - QGIS project file
- `ignore_mobile/` - Methods docs and templates (not synced to phones)

## Pending Tasks

### Environment Consolidation (#186)
- **Ready**: `environment_test_simplified.yml` is tested and working for both rfp scripts and mergin-client
- **TODO**:
  1. Rename `environment_test_simplified.yml` to `environment.yml` (replace root environment.yml)
  2. Remove old conda environments: `dff`, `dff2`, `dff_test`, `dff_test_simplified`
  3. Remove old environment files: `scripts/qgis/environment.yml`, `environment_test.yml`
  4. Update CLAUDE.md to reflect single unified `dff` environment
  5. Commit changes to close #186

### Performance Testing
- **TODO**: Resolve #189 (handle veg_comp layer as unzipped .fgb)
- **TODO**: Run clean performance tests without veg_comp errors for accurate comparison (#188)
- **TODO**: Test both methods (streaming vs download-first) with network contention (S3 backup running)

### SRED Documentation
- **TODO**: Update commit-sred skill to be project/milestone aware like create-issue
- **TODO**: Create SRED issue about LLM timing methodology for GIS workflow improvements
