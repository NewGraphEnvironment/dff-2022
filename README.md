# dff-2022

Workflows to create digital field forms and QGIS projects that integrate with [Mergin Maps](https://merginmaps.com/?gclid=Cj0KCQjwnvOaBhDTARIsAJf8eVPAtSEg0pF915dFv6b4kge16gvwTRnX75S0gEB4Xj2wRZevorN3n3EaAhSrEALw_wcB) for field data collection related to fish passage assessment, habitat assessment and stream crossing climate change/maintenance issue risk assessment

## Digital Field Forms

Standardized provincial submission templates used to generate digital field form skeletons imported and modified with `scripts/build_*` scripts include:

-   Fish Passage - [pscis_assessment_template_v24.xls](https://www2.gov.bc.ca/gov/content/environment/plants-animals-ecosystems/fish/aquatic-habitat-management/fish-passage/fish-passage-technical/assessment-projects)

-   Fish Passage - [Fish Data Submission Spreadsheet Template - V 2.0, January 20, 2020 (FDS_Template2021-01-28.xls)](https://www2.gov.bc.ca/gov/content/environment/plants-animals-ecosystems/fish/fish-and-fish-habitat-data-information/fish-data-submission/submit-fish-data#submitfish)

At this point the forms are intended to be tidied using R scripts (currently housed in project specific repositories) and exported to csv for copy and paste into standardized submission templates that can be submitted to the province. However, there is currently more information gathered that can be used for custom reporting including road/stream crossing climate change risk and maintenance issue risk assessment.

## QGIS Projects to Sync and Serve on IOS and Android phones/tablets

QGIS project layers (with the exception of field forms) clipped to [watershed group areas](https://catalogue.data.gov.bc.ca/dataset/freshwater-atlas-watershed-groups) in British Columbia are bulk downloaded from the [BC Data Catalogue](https://catalogue.data.gov.bc.ca/dataset?download_audience=Public), [Hillcrest Geographics server](https://www.hillcrestgeo.ca/outgoing/fishpassage/data/bcfishpass/outputs/), [fwapg](https://features.hillcrestgeo.ca/fwa/), and [Provincial Government FTP site](https://www2.gov.bc.ca/gov/content/data/geographic-data-services/topographic-data/roads) using [`bcdata`](https://github.com/smnorris/bcdata), `ogr2ogr` and `wget` by running `scripts/background_layers.sh` and specifying watershed groups of interest as a comma separated, single quoted string eg.

`$ ./background_layers.sh "'VICT','COWN'"`

`qml` files which provide `QGIS` styling for forms are kept in the `data` directory along with `QGIS` project `qlr` file that can be used to provide styling for all project layers.

## eDNA lookup tables

The eDNA assay table (species, assay and dye) and the lab's group run order moved out of `data/` in 2026-10. The current copies are at [m1rr0r `dna/`](https://github.com/NewGraphEnvironment/m1rr0r/tree/main/dna).

## Code of Conduct

Please note that the this project is released with a [Contributor Code of Conduct](https://contributor-covenant.org/version/2/0/CODE_OF_CONDUCT.html). By contributing to this project, you agree to abide by its terms.
