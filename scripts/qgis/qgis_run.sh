#!/bin/bash
set -euo pipefail

# Usage: ./qgis_run.sh /path/to/script.py [args...]
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/script.py [args...]"
  exit 1
fi

SCRIPT="$1"; shift

# Prefer LTR if installed; fall back to stable
QGIS_APP_LTR="/Applications/QGIS-LTR.app"
QGIS_APP_STD="/Applications/QGIS.app"
QGIS_APP="${QGIS_APP_STD}"
[[ -d "$QGIS_APP_LTR" ]] && QGIS_APP="$QGIS_APP_LTR"

QGIS_RESOURCES="$QGIS_APP/Contents/Resources"
QGIS_PY="$QGIS_APP/Contents/MacOS/bin/python3"
QGIS_SETUP="$QGIS_APP/Contents/MacOS/bin/qgis_setup.sh"

# Minimal env (sourcing setup script is most robust on macOS)
export QGIS_PREFIX_PATH="$QGIS_RESOURCES"
export PYTHONPATH="$QGIS_RESOURCES/python:${PYTHONPATH:-}"
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}"  # headless

# Optional: source full QGIS env if available
[[ -f "$QGIS_SETUP" ]] && source "$QGIS_SETUP"

# Checks
[[ -x "$QGIS_PY" ]] || { echo "QGIS python not found at $QGIS_PY"; exit 1; }
[[ -f "$SCRIPT" ]] || { echo "Python script not found: $SCRIPT"; exit 1; }

# Quick import test
"$QGIS_PY" - <<'PY'
from qgis.core import QgsApplication
print("QGIS import OK")
PY

# Run script, passing through all args
exec "$QGIS_PY" "$SCRIPT" "$@"

