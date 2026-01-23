# Performance Testing Logs

This directory contains performance testing logs for `rfp_source_aws.sh` optimizations.

## Testing Methodology

See [#188](https://github.com/NewGraphEnvironment/dff-2022/issues/188) for context.

### Test Configuration

**Standard test layers** (for comparability):
- bcfishpass.crossings_vw
- whse_forest_tenure.ften_road_section_lines_svw
- bcfishobs.fiss_fish_obsrvtn_events_vw

**Watershed group:** ADMS

**Network conditions tested:**
1. Clean network (S3 backup paused)
2. With concurrent S3 backup (simulates real-world usage)

### Running Tests

```bash
# Start monitoring in background
./monitor_rfp.sh background_layers.gpkg logs/test_name.log &

# Run script
./rfp_source_aws.sh 'ADMS'
```

### Log Naming Convention

- `download_first_YYYYMMDD.log` - Download-then-process approach
- `vsizip_vsicurl_YYYYMMDD.log` - Original streaming approach
- `*_with_backup.log` - Tested with concurrent S3 backup running

## Results

Logs committed here document performance comparisons for SRED tracking.
