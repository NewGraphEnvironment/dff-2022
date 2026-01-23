# `rfp_source_bcdata.sh`, `rfp_source_aws.sh`, `rfp_source_fwa.sh` and `rfp_qgis_create_bcfishpass.sh`
These are the scripts for creating QGIS projects.  

Requires virtual environment built with follow run from **`scripts/qgis`** (mergin-client environment is in main directory and title dff2):
    
    conda env create -f environment.yml
    conda activate dff

**Note: Project directory defined in call to 
`qgis_create.sh` must not be present at ~Projects/gis/{project_directory} or it will not be created.**

To download and clip layers for an area of interest defined by a list of watershed groups and load to a geopackage:


## `rfp_source_bcdata.sh`

  1. edit `rfp_source_bcdata.txt` as needed, listing all layers to be downloaded via bcdata/WFS 
  2. source the file and include **double quoted list of single quoted** (ex. "'BULK', 'KLUM'") watershed groups to run
  the script and define the study area boundaries.
  3.To update an existing `background_layers.gpkg` file non-interactively - include the `update` flag.  Ff a file named
  `background_layers.gpkg` exists in the `scripts/qgis` directory it will ask the user if they want to start over (yes)
  or update the existing geopackage (no).
  4. Once input has been put to console the script will download `rfp_source_bcdata.txt` layers to `.geojson`, for given
  study area (optionally with timer - `time `) and load to `background_layers.gpkg` with clip associated with
  watershed group polygons supplied in command to run the script:
  
    
    Non interactive:
    
    time ./rfp_source_bcdata.sh "'BULK', 'KLUM" "update"
    
    
    Interactive update if `background_layers.gpkg` exists in `scripts/qgis` directory and non-interactive if it does not:
    
    time ./rfp_source_bcdata.sh "'BULK', 'KLUM'"
  
If downloads in `rfp_source_bcdata.sh` fail, re-run `rfp_source_bcdata.sh` until downloads are complete.


## `rfp_source_fwa.sh`

1. **Edit your layer list**  
   In `rfp_source_fwa.txt`, list one FWA collection per line. Optionally you can hash out (put # in front) entries to exclude. 
   Available collections live at:  
   https://features.hillcrestgeo.ca/fwa/collections


3. **Run the script**  
Non interactive:
   ```bash
   time ./rfp_source_fwa.sh "'BULK', 'MORR'" "update"
   ```
   
Interactive:
   ```bash
   time ./rfp_source_fwa.sh "'BULK', 'MORR'"
   ```
   
   
## rfp_source_aws.sh  
  1. download data from file sources stored on `aws` and load to `background_layers.gpkg` (and produce stand alone `lateral_habitat.tif`) 
  with clip from watershed group polygons.  Note that the `background_layers.gpkg` must be in the `scripts/qgis` directory:
  
  		
    time ./rfp_source_aws.sh "'BULK', 'KLUM'"
  		
  		

## `rfp_qgis_create.sh` 

Script will create the directory where the spatial layers, digital field forms (fiss site and pscis assessment) will be 
burned and styled as part of a QGIS project.  This project can subsequently be turned into a mergin project on the cloud 
for collaboration. Define the 1. name of the directory to be created and 2. name of the QGIS `.qgs` project template file
(options are "bcfishpass_mobile.qgs" or "restoration_mobile.qgs") for the project by including it in quotes as part of 
the argument to run the script. "bcfishpass_mobile.qgs" or "bcrestoration_mobile.qgs" are stored in the `data/qgis` directory 
of this repo. 
  
        
    time ./rfp_qgis_create.sh "new_project_directory" "bcrestoration_mobile.qgs"
    

    
**Or run everything at the same time**
  		

    time ./rfp_source_bcdata.sh "'ADMS'" && 
    time ./rfp_source_aws.sh "'ADMS'" && 
    time ./rfp_source_fwa.sh "'ADMS'" && 
    time ./rfp_qgis_create.sh "rfp_test4" "bcrestoration_mobile.qgs"


**For updates to existing projects we copy the `background_layers.gpkg` from an existing project to the repo then run one or more of 
the `rfp_source_{}.sh` files.  This will update the `background_layers.gpkg` with new data and in the
case of `rfp_source_aws.sh` will produce a new `habitat_lateral.tif` file**.  Here is an example of how to do this:
  
    cp ~/Projects/gis/rfp_test/background_layers.gpkg ~/Projects/repo/dff-2022/scripts/qgis/background_layers.gpkg
  
  <br>
  
Run the update:
  
    time ./rfp_source_bcdata.sh "'BULK', 'KLUM'" "update" && time ./rfp_source_aws.sh "'BULK', 'KLUM'"
    
    time ./rfp_source_bcdata.sh "'ADMS'" "update" && time ./rfp_source_aws.sh "'BULK'"

  
  <br>
  
Move the `gpkg` and the `tiff` back to its directory:
  
    mv ~/Projects/repo/dff-2022/scripts/qgis/background_layers.gpkg ~/Projects/gis/rfp_test/background_layers.gpkg
    
    mv ~/Projects/repo/dff-2022/scripts/qgis/habitat_lateral.tif ~/Projects/gis/rfp_test/habitat_lateral.tif
    
Note - if `background_layers.gpkg` is present and `update` is not provided as the second argument to `rfp_source_bcdata.sh`
the script will ask the user if they want to start over (yes) or update the existing geopackage (no).


## Performance Testing

Performance tests are available to compare different approaches for downloading and processing layers. Tests run the full workflow (bcdata → aws → fwa → create) and log timing for each step.

### Running Performance Tests

Run a full workflow test with automated logging:

```bash
# Test with single watershed group
./test_performance.sh "test_project_name" "'ADMS'" "bcrestoration_mobile.qgs"

# Test with multiple watershed groups
./test_performance.sh "test_bulk" "'BULK', 'MORR', 'KLUM'" "bcrestoration_mobile.qgs"
```

Test results are saved to `logs/test_<project_name>_<timestamp>.log`.

### Generating Performance Summaries

Parse test logs into a markdown summary table:

```bash
# With explicit file pattern
./test_performance_sum.sh logs/test_*.log

# Or use the default (no arguments needed)
./test_performance_sum.sh

# Or specific files
./test_performance_sum.sh logs/test_visi_20260122.log logs/test_dl_20260122.log
```

This generates `test_performance_sum.md` with timing comparisons showing:
- Test configuration (watershed groups, layer count)
- Individual step timing (bcdata, aws, fwa, create)
- Total execution time
- Notes on any errors or issues

### Performance Findings

**Current approach comparison (rfp_source_aws.sh):**

Two methods tested for downloading S3 layers:
- **Streaming**: `/vsizip/vsicurl/` - streams zipped files over HTTP, unzips on-the-fly
- **Download-first**: Downloads zip locally with wget, unzips, processes, cleans up

**Results:**
- Small scale (1 watershed, 3 layers): Streaming slightly faster
- Medium scale (3 watersheds, 3 layers): Download-first ~6% faster
- Large scale (7 watersheds, 9 layers): Download-first ~2% faster

Download-first advantage increases with more watershed groups (more clipping operations on the same downloaded file).

**Network conditions impact:** Concurrent S3 operations (backups/uploads) significantly slow streaming performance. Use `kill -STOP $(pgrep s3cmd)` to pause, `kill -CONT $(pgrep s3cmd)` to resume.

Test results tracked in `logs/` directory for reproducibility and SRED documentation.


## Create a Mergin project and share

    mergin create newgraph/rfp_test --from-dir ~/Projects/gis/rfp_test

    mergin share-add newgraph/rfp_test newgraph_bute --permissions writer


