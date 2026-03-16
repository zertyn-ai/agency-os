#!/bin/bash
#
# agency-codex-init.sh — Initialize project codex
#
# Creates project-codex.yaml in the project root.
# Usage: bash agency-codex-init.sh [project-path]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENCY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_PATH="${1:-.}"
cd "$PROJECT_PATH" 2>/dev/null || exit 1

PROJECT_NAME=$(basename "$(pwd)")
CODEX_FILE="project-codex.yaml"

# Don't overwrite existing codex
if [ -f "$CODEX_FILE" ]; then
  echo "Codex already exists: $CODEX_FILE"
  if [ "${2:-}" != "--force" ]; then
    exit 0
  fi
  echo "Updating health section..."
fi

# Detect stack
STACK="unknown"
if [ -f "package.json" ]; then
  if grep -q "next" package.json 2>/dev/null; then STACK="nextjs"
  elif grep -q "expo" package.json 2>/dev/null; then STACK="expo"
  elif grep -q "react" package.json 2>/dev/null; then STACK="react"
  else STACK="node"; fi
elif [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
  if grep -q "fastapi\|FastAPI" pyproject.toml setup.py 2>/dev/null; then STACK="fastapi"
  elif grep -q "django\|Django" pyproject.toml setup.py 2>/dev/null; then STACK="django"
  else STACK="python"; fi
fi

# Quality snapshot for health
TEST_COUNT=0
TEST_PASS_RATE="0.00"
TYPE_ERRORS=0

if [ -x "$AGENCY_DIR/scripts/agency-quality-snapshot.sh" ]; then
  SNAPSHOT=$(bash "$AGENCY_DIR/scripts/agency-quality-snapshot.sh" "$(pwd)" 2>/dev/null || echo "{}")

  extract_val() {
    echo "$SNAPSHOT" | grep "\"$1\"" | head -1 | sed 's/.*: *\([0-9.]*\).*/\1/' || echo "0"
  }

  TEST_COUNT=$(extract_val "test_count")
  TEST_PASS=$(extract_val "test_pass_count")
  TYPE_ERRORS=$(extract_val "type_error_count")

  TEST_COUNT=${TEST_COUNT:-0}
  TEST_PASS=${TEST_PASS:-0}
  TYPE_ERRORS=${TYPE_ERRORS:-0}

  if [ "$TEST_COUNT" -gt 0 ] 2>/dev/null; then
    TEST_PASS_RATE=$(awk "BEGIN {printf \"%.2f\", $TEST_PASS / $TEST_COUNT}")
  fi
fi

# Collect failed approaches from error.log
FAILED_APPROACHES=""
LIVE_DIR="$AGENCY_DIR/live/$PROJECT_NAME"
if [ -f "$LIVE_DIR/error.log" ] && [ -s "$LIVE_DIR/error.log" ]; then
  while IFS= read -r line; do
    clean=$(echo "$line" | sed 's/^\[.*\] //' | sed 's/"/\\"/g' | head -c 200)
    [ -n "$clean" ] && FAILED_APPROACHES="${FAILED_APPROACHES}  - \"$clean\"
"
  done < <(tail -10 "$LIVE_DIR/error.log" 2>/dev/null | sort -u)
fi

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

cat > "$CODEX_FILE" << EOF
# project-codex.yaml — Machine-maintained project intelligence.
# Generated: $TIMESTAMP

# Human-editable section — agents read but don't modify:
principles: []

# Agent-maintained sections:
gotchas: []

failed_approaches:
${FAILED_APPROACHES:-  []}

health:
  last_scan: "$TIMESTAMP"
  test_count: $TEST_COUNT
  test_pass_rate: $TEST_PASS_RATE
  type_errors: $TYPE_ERRORS
  stack: "$STACK"
EOF

echo "Created $CODEX_FILE for $PROJECT_NAME (stack: $STACK, tests: $TEST_COUNT)"
