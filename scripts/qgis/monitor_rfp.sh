#!/bin/bash
# Monitor rfp_source_aws.sh performance
# Tracks layer processing timing for performance comparison

START_TIME=$(date +%s)
GPKG="${1:-background_layers.gpkg}"
LOG="${2:-logs/rfp_timing_$(date +%Y%m%d_%H%M%S).log}"

# Create logs directory if it doesn't exist
mkdir -p "$(dirname "$LOG")"

echo "=== rfp_source_aws.sh Performance Monitor ===" > "$LOG"
echo "Start time: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG"
echo "GPKG: $GPKG" >> "$LOG"
echo "" >> "$LOG"

LAST_SIZE=0
LAYER_COUNT=0

while ps aux | grep -v grep | grep "rfp_source_aws.sh" > /dev/null; do
  if [ -f "$GPKG" ]; then
    CURRENT_SIZE=$(stat -f%z "$GPKG" 2>/dev/null || stat -c%s "$GPKG" 2>/dev/null)
    if [ "$CURRENT_SIZE" != "$LAST_SIZE" ] && [ "$LAST_SIZE" != "0" ]; then
      ELAPSED=$(($(date +%s) - START_TIME))
      LAYER_COUNT=$((LAYER_COUNT + 1))
      SIZE_MB=$((CURRENT_SIZE / 1024 / 1024))
      echo "Layer $LAYER_COUNT completed at $(date '+%H:%M:%S') - Elapsed: ${ELAPSED}s - Size: ${SIZE_MB}MiB" >> "$LOG"
    fi
    LAST_SIZE=$CURRENT_SIZE
  fi
  sleep 2
done

END_TIME=$(date +%s)
TOTAL_ELAPSED=$((END_TIME - START_TIME))

echo "" >> "$LOG"
echo "=== COMPLETED ===" >> "$LOG"
echo "End time: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG"
echo "Total time: ${TOTAL_ELAPSED}s" >> "$LOG"
if [ $LAYER_COUNT -gt 0 ]; then
  echo "Total layers: $LAYER_COUNT" >> "$LOG"
  echo "Average time per layer: $((TOTAL_ELAPSED / LAYER_COUNT))s" >> "$LOG"
fi

cat "$LOG"
