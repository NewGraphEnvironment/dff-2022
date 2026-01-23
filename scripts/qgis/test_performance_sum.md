# QGIS Project Creation Performance Tests

## Test Results Summary

| Test ID | Date | Method | Watersheds | Layers | bcdata (s) | aws (s) | fwa (s) | create (s) | Total (s) | Notes |
|---------|------|--------|------------|--------|------------|---------|---------|------------|-----------|-------|
| perf_old_full_20260122_200628 | 2026-01-22 | streaming | 7 wshd | 0
? | 0.0 | 0.0 | 0.1 | 0.02 | 0.1 | Env issue |
| rfp_dl_002_7wshd_20260122_202737 | 2026-01-22 | download | 7 wshd | 16 | 11.4 | 939.1 | 4.8 | 0.04 | 955.4 | Missing layers |
| rfp_visi_002_7wshd_20260122_201122 | 2026-01-22 | streaming | 7 wshd | 0
? | 13.7 | 956.7 | 4.9 | 0.08 | 975.4 | ERRORS |
| rfp_visi_003_7wshd_7aws_layers_20260122_205610 | 2026-01-22 | streaming | 7 wshd | 0
? | 24.3 | 0.0 | 0.0 | 0.00 | 24.3 |  |
| test_download_20260122_173032 | 2026-01-22 | download | 3 wshd | 6 | 9.3 | 134.8 | 0.0 | 0.00 | 144.1 |  |
| test_visi_20260122_172347 | 2026-01-22 | streaming | 1 wshd | 0
? | 0.0 | 0.0 | 0.0 | 0.00 | 0.0 |  |

## Notes

- **Method**:
  - `streaming`: Uses `/vsizip/vsicurl/` to stream files from S3
  - `download`: Downloads files locally first, then processes

- **Timing Columns**:
  - `bcdata`: BC Data Catalogue layer downloads
  - `aws`: S3 layer processing (main performance test target)
  - `fwa`: Freshwater Atlas layer downloads
  - `create`: QGIS project file creation

- **Watersheds**: Number of watershed groups tested
- **Layers**: Number of AWS layers processed (? if not determinable from log)

## Test Conditions

All tests run on:
- Machine: MacBook Pro (M-series)
- Environment: dff_test conda environment
- Network: Variable (some tests with concurrent S3 backup running)

