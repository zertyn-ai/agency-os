#!/bin/bash
#
# agency-quality-compare.sh — Compare two quality snapshots
#
# Usage: bash agency-quality-compare.sh <before.json> <after.json> [project-path]
# Output: "ok", "regressed", or "improved"
#
# Regression = test_pass_count decreased OR type_error_count increased
# Flaky test protection: if regression detected, re-runs snapshot once before verdict.

set -uo pipefail

BEFORE="${1:?Usage: agency-quality-compare.sh <before.json> <after.json> [project-path]}"
AFTER="${2:?Usage: agency-quality-compare.sh <before.json> <after.json> [project-path]}"
PROJECT_PATH="${3:-$(pwd)}"

[ ! -f "$BEFORE" ] && { echo "ok"; exit 0; }
[ ! -f "$AFTER" ] && { echo "ok"; exit 0; }

extract() {
  local file="$1" key="$2"
  grep "\"$key\"" "$file" 2>/dev/null | head -1 | sed "s/.*\"$key\"[^0-9]*\([0-9]*\).*/\1/" || echo "0"
}

BEFORE_PASS=$(extract "$BEFORE" "test_pass_count")
AFTER_PASS=$(extract "$AFTER" "test_pass_count")
BEFORE_TYPES=$(extract "$BEFORE" "type_error_count")
AFTER_TYPES=$(extract "$AFTER" "type_error_count")

BEFORE_PASS=${BEFORE_PASS:-0}
AFTER_PASS=${AFTER_PASS:-0}
BEFORE_TYPES=${BEFORE_TYPES:-0}
AFTER_TYPES=${AFTER_TYPES:-0}

REGRESSED=false
[ "$AFTER_PASS" -lt "$BEFORE_PASS" ] 2>/dev/null && REGRESSED=true
[ "$AFTER_TYPES" -gt "$BEFORE_TYPES" ] 2>/dev/null && REGRESSED=true

# Flaky test protection: re-run once
if [ "$REGRESSED" = true ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  RERUN_FILE="/tmp/agency-quality-rerun-$$.json"

  if [ -x "$SCRIPT_DIR/agency-quality-snapshot.sh" ]; then
    bash "$SCRIPT_DIR/agency-quality-snapshot.sh" "$PROJECT_PATH" > "$RERUN_FILE" 2>/dev/null || true

    if [ -f "$RERUN_FILE" ]; then
      RERUN_PASS=$(extract "$RERUN_FILE" "test_pass_count")
      RERUN_TYPES=$(extract "$RERUN_FILE" "type_error_count")
      RERUN_PASS=${RERUN_PASS:-0}
      RERUN_TYPES=${RERUN_TYPES:-0}

      STILL_REGRESSED=false
      [ "$RERUN_PASS" -lt "$BEFORE_PASS" ] 2>/dev/null && STILL_REGRESSED=true
      [ "$RERUN_TYPES" -gt "$BEFORE_TYPES" ] 2>/dev/null && STILL_REGRESSED=true

      [ "$STILL_REGRESSED" = false ] && REGRESSED=false
    fi
    rm -f "$RERUN_FILE"
  fi
fi

if [ "$REGRESSED" = true ]; then
  echo "regressed"
elif [ "$AFTER_PASS" -gt "$BEFORE_PASS" ] 2>/dev/null || [ "$AFTER_TYPES" -lt "$BEFORE_TYPES" ] 2>/dev/null; then
  echo "improved"
else
  echo "ok"
fi
