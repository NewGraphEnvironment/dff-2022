#!/bin/bash
set -euo pipefail

# Usage: ./qgis_run.sh /path/to/script.py

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/script.py"
  exit 1
fi

SCRIPT="$1"

# QGIS app bundle (update if using QGIS-LTR.app)
QGIS_APP="/Applications/QGIS.app"
QGIS_RESOURCES="$QGIS_APP/Contents/Resources"
QGIS_PY="$QGIS_APP/Contents/MacOS/bin/python3"

# Exports (bundled python often works without, but safe to keep)
export QGIS_PREFIX_PATH="$QGIS_RESOURCES"
export PYTHONPATH="$QGIS_RESOURCES/python:${PYTHONPATH:-}"

# Checks
[[ -x "$QGIS_PY" ]] || { echo "QGIS python not found at $QGIS_PY"; exit 1; }
[[ -f "$SCRIPT" ]] || { echo "Python script not found: $SCRIPT"; exit 1; }

# Quick import test
"$QGIS_PY" - <<'PY'
from qgis.core import QgsApplication
print("QGIS import OK")
PY

# Run the given Python script
exec "$QGIS_PY" "$SCRIPT"
