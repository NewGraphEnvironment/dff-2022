#!/bin/bash
# Summarize performance test results from logs
# Generates a CSV that appends results
# Usage: ./summarize_test_results.sh [logs/*.log]

# Output file
OUTPUT="test_performance_sum.csv"

# Create header only if file doesn't exist
if [[ ! -f "$OUTPUT" ]]; then
    echo "test_id,datetime,method,watersheds,layers,bcdata_s,aws_s,fwa_s,create_s,total_s,notes" > "$OUTPUT"
fi

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
for logfile in ${@:-logs/*.log}; do
    if [[ ! -f "$logfile" ]]; then
        continue
    fi

    # Extract test name and date from filename
    basename=$(basename "$logfile" .log)

    # Handle new naming format: YYYYMMDD_HHMMSS_test_name
    if [[ "$basename" =~ ^([0-9]{8})_([0-9]{6})_(.+)$ ]]; then
        date_raw="${BASH_REMATCH[1]}"
        time_raw="${BASH_REMATCH[2]}"
        date=$(echo "$date_raw" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3/')
        time=$(echo "$time_raw" | sed 's/\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1:\2:\3/')
        datetime="$date $time"
        test_name="${BASH_REMATCH[3]}"
    else
        # Fallback to old format: test_name_YYYYMMDD_HHMMSS
        test_name=$(echo "$basename" | cut -d'_' -f2-)
        date=$(echo "$basename" | grep -o '[0-9]\{8\}' | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3/')
        datetime="$date"
    fi

    # Determine method from test name
    if [[ "$test_name" == *"visi"* ]] || [[ "$test_name" == *"old"* ]]; then
        method="streaming"
    elif [[ "$test_name" == *"dl"* ]] || [[ "$test_name" == *"download"* ]]; then
        method="download"
    else
        method="unknown"
    fi

    # Extract watershed groups
    watersheds=$(grep "Watershed groups:" "$logfile" | head -1 | cut -d: -f2- | tr -d "'" | xargs | tr -d '\n')
    wshd_count=$(echo "$watersheds" | tr ',' '\n' | wc -l | xargs | tr -d '\n')

    # Count layers from log (look for "Processing" lines in aws section)
    layer_count=$(grep -c "Processing.*\.\.\." "$logfile" 2>/dev/null)
    layer_count=$(echo "$layer_count" | tr -d '\n ')
    # If layer_count is 0, mark as unknown
    if [[ "$layer_count" == "0" ]]; then
        layer_count="?"
    fi

    # Extract timing data (first 4 "real" times correspond to bcdata, aws, fwa, create)
    times=($(grep "^real" "$logfile" | head -4 | awk '{print $2}'))

    # Convert times to seconds and sanitize
    bcdata_s=$(time_to_seconds "${times[0]:-0m0s}")
    aws_s=$(time_to_seconds "${times[1]:-0m0s}")
    fwa_s=$(time_to_seconds "${times[2]:-0m0s}")
    create_s=$(time_to_seconds "${times[3]:-0m0s}")

    # Calculate total (sanitize inputs for bc)
    bcdata_s=$(echo "$bcdata_s" | tr -d '\n ')
    aws_s=$(echo "$aws_s" | tr -d '\n ')
    fwa_s=$(echo "$fwa_s" | tr -d '\n ')
    create_s=$(echo "$create_s" | tr -d '\n ')
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
    notes=$(echo "$notes" | tr -d '\n')

    # Only add row if we have actual timing data
    if [[ "$total_s" != "0" ]] && [[ "$total_s" != ".00" ]]; then
        printf "%s,%s,%s,%d,%s,%.1f,%.1f,%.1f,%.2f,%.1f,%s\n" \
            "$test_name" "$datetime" "$method" "$wshd_count" "$layer_count" \
            "$bcdata_s" "$aws_s" "$fwa_s" "$create_s" "$total_s" "$notes" >> "$OUTPUT"
    fi
done

echo "Results appended to: $OUTPUT"
echo ""
echo "Recent entries:"
tail -5 "$OUTPUT" | column -t -s','
