#!/bin/bash
# Performance comparison test for rfp_source_aws.sh
# Run from scripts/qgis directory
# Usage: ./test_performance.sh PROJECT_NAME WATERSHED_GROUPS [TEMPLATE]
# Example: ./test_performance.sh test1 "'BULK', 'MORR', 'KLUM'"

PROJECT_NAME="${1:-rfp_test}"
WATERSHED="${2:-'ADMS'}"
TEMPLATE="${3:-bcrestoration_mobile.qgs}"

# Must run from scripts/qgis directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Performance Test ==="
echo "Project name: $PROJECT_NAME"
echo "Watershed groups: $WATERSHED"
echo "Template: $TEMPLATE"
echo "Running from: $SCRIPT_DIR"
echo ""

# Check if S3 backup is running
if pgrep -f "s3cmd" > /dev/null; then
    echo "WARNING: s3cmd backup is running - will affect results"
    read -p "Continue anyway? (y/n): " answer
    [[ $answer != "y" ]] && exit 0
fi

# Clean up old gpkg
rm -f background_layers.gpkg

echo ""
echo "=== Testing current rfp_source_aws.sh version ==="
echo ""

# Create log file
LOGFILE="logs/test_${PROJECT_NAME}_$(date +%Y%m%d_%H%M%S).log"
echo "=== Performance Test: $PROJECT_NAME ===" > "$LOGFILE"
echo "Watershed groups: $WATERSHED" >> "$LOGFILE"
echo "Template: $TEMPLATE" >> "$LOGFILE"
echo "Date: $(date)" >> "$LOGFILE"
echo "" >> "$LOGFILE"

# Run full workflow and capture timing
echo "Starting full workflow..."

echo "=== rfp_source_bcdata.sh ===" | tee -a "$LOGFILE"
( time ./rfp_source_bcdata.sh "$WATERSHED" ) 2>&1 | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"

echo "=== rfp_source_aws.sh ===" | tee -a "$LOGFILE"
( time ./rfp_source_aws.sh "$WATERSHED" ) 2>&1 | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"

echo "=== rfp_source_fwa.sh ===" | tee -a "$LOGFILE"
( time ./rfp_source_fwa.sh "$WATERSHED" ) 2>&1 | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"

echo "=== rfp_qgis_create.sh ===" | tee -a "$LOGFILE"
( time ./rfp_qgis_create.sh "$PROJECT_NAME" "$TEMPLATE" ) 2>&1 | tee -a "$LOGFILE"

echo ""
echo "=== Test complete! ==="
echo ""
echo "Results saved to: $LOGFILE"
echo "Project created at: ~/Projects/gis/$PROJECT_NAME/"
echo ""
tail -50 "$LOGFILE" | grep "real"
