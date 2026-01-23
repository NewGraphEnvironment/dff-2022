#!/bin/bash
# Summarize performance test results from logs
# Generates a markdown table with timing comparisons
# Usage: ./summarize_test_results.sh [logs/*.log]

# Output file
OUTPUT="test_performance_sum.md"

# Header
cat > "$OUTPUT" << 'EOF'
# QGIS Project Creation Performance Tests

## Test Results Summary

| Test ID | Date | Method | Watersheds | Layers | bcdata (s) | aws (s) | fwa (s) | create (s) | Total (s) | Notes |
|---------|------|--------|------------|--------|------------|---------|---------|------------|-----------|-------|
EOF

# Function to convert time format (Xm Ys) to seconds
time_to_seconds() {
    local time_str="$1"
    # Extract minutes and seconds
    local mins=$(echo "$time_str" | grep -o '[0-9]*m' | tr -d 'm')
    local secs=$(echo "$time_str" | grep -o '[0-9.]*s' | tr -d 's')

    # Default to 0 if empty
    mins=${mins:-0}
    secs=${secs:-0}

    # Calculate total seconds
    echo "scale=2; $mins * 60 + $secs" | bc
}

# Parse each log file
for logfile in ${@:-logs/test_*.log}; do
    if [[ ! -f "$logfile" ]]; then
        continue
    fi

    # Extract test name and date from filename
    basename=$(basename "$logfile" .log)
    test_name=$(echo "$basename" | cut -d'_' -f2-)
    date=$(echo "$basename" | grep -o '[0-9]\{8\}' | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3/')

    # Determine method from test name
    if [[ "$test_name" == *"visi"* ]] || [[ "$test_name" == *"old"* ]]; then
        method="streaming"
    elif [[ "$test_name" == *"dl"* ]] || [[ "$test_name" == *"download"* ]]; then
        method="download"
    else
        method="unknown"
    fi

    # Extract watershed groups
    watersheds=$(grep "Watershed groups:" "$logfile" | head -1 | cut -d: -f2- | tr -d "'" | xargs)
    wshd_count=$(echo "$watersheds" | tr ',' '\n' | wc -l | xargs)

    # Count layers from log (look for "Processing" lines in aws section)
    layer_count=$(grep -c "Processing.*\.\.\." "$logfile" 2>/dev/null || echo "?")

    # Extract timing data (first 4 "real" times correspond to bcdata, aws, fwa, create)
    times=($(grep "^real" "$logfile" | head -4 | awk '{print $2}'))

    # Convert times to seconds
    bcdata_s=$(time_to_seconds "${times[0]:-0m0s}")
    aws_s=$(time_to_seconds "${times[1]:-0m0s}")
    fwa_s=$(time_to_seconds "${times[2]:-0m0s}")
    create_s=$(time_to_seconds "${times[3]:-0m0s}")

    # Calculate total
    total_s=$(echo "$bcdata_s + $aws_s + $fwa_s + $create_s" | bc)

    # Extract any errors/notes
    notes=""
    if grep -q "ERROR" "$logfile"; then
        notes="ERRORS"
    elif grep -q "404 Not Found" "$logfile"; then
        notes="Missing layers"
    elif grep -q "command not found" "$logfile"; then
        notes="Env issue"
    fi

    # Only add row if we have actual timing data
    if [[ "$total_s" != "0" ]] && [[ "$total_s" != ".00" ]]; then
        printf "| %s | %s | %s | %d wshd | %s | %.1f | %.1f | %.1f | %.2f | %.1f | %s |\n" \
            "$test_name" "$date" "$method" "$wshd_count" "$layer_count" \
            "$bcdata_s" "$aws_s" "$fwa_s" "$create_s" "$total_s" "$notes" >> "$OUTPUT"
    fi
done

# Add notes section
cat >> "$OUTPUT" << 'EOF'

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

EOF

echo "Results written to: $OUTPUT"
cat "$OUTPUT"
