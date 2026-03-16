#!/bin/bash
#
# session-metrics.sh — SessionEnd hook
# Collects session metrics and writes JSON to metrics/.
# JSONL only — no SQLite.

set -uo pipefail

AGENCY_DIR="${AGENCY_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
METRICS_DIR="$AGENCY_DIR/metrics"
PROJECT_NAME=$(basename "$(pwd)" 2>/dev/null || echo "unknown")
SESSION_DIR="$AGENCY_DIR/live/$PROJECT_NAME"
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

mkdir -p "$METRICS_DIR"

# Skip if no live session
[ ! -d "$SESSION_DIR" ] && exit 0

# Duration
DURATION=0
if [ -f "$SESSION_DIR/session.started_at" ]; then
  STARTED=$(cat "$SESSION_DIR/session.started_at" 2>/dev/null || echo "0")
  [ -n "$STARTED" ] && DURATION=$(( $(date +%s) - STARTED ))
fi

# Task counts
DONE=0
FAILED=0
TOTAL=0
SUCCESSES="[]"
SUCCESS_LIST=""

if [ -d "$SESSION_DIR/tasks" ]; then
  for status_file in "$SESSION_DIR/tasks"/*.status; do
    [ -f "$status_file" ] || continue
    tid=$(basename "$status_file" .status)
    status=$(cat "$status_file" 2>/dev/null || echo "unknown")
    TOTAL=$((TOTAL + 1))
    case "$status" in
      done|completed)
        DONE=$((DONE + 1))
        task_duration=0
        if [ -f "$SESSION_DIR/tasks/$tid.started_at" ] && [ -f "$SESSION_DIR/tasks/$tid.completed_at" ]; then
          s=$(cat "$SESSION_DIR/tasks/$tid.started_at" 2>/dev/null || echo "0")
          e=$(cat "$SESSION_DIR/tasks/$tid.completed_at" 2>/dev/null || echo "0")
          [ -n "$s" ] && [ -n "$e" ] && task_duration=$((e - s))
        fi
        entry="{\"task_id\":\"$tid\",\"duration\":$task_duration}"
        SUCCESS_LIST="${SUCCESS_LIST:+$SUCCESS_LIST,}$entry"
        ;;
      failed|error)
        FAILED=$((FAILED + 1))
        ;;
    esac
  done
  [ -n "$SUCCESS_LIST" ] && SUCCESSES="[$SUCCESS_LIST]"
fi

# Error count from error.log
ERRORS=0
if [ -f "$SESSION_DIR/error.log" ]; then
  ERRORS=$(wc -l < "$SESSION_DIR/error.log" | tr -d ' ')
fi

# Commit count (today)
COMMITS=$(git log --since="6am today" --oneline 2>/dev/null | wc -l | tr -d ' ')

# Write metrics JSON
cat > "$METRICS_DIR/${DATE}_${PROJECT_NAME}.json" << EOF
{
  "project": "$PROJECT_NAME",
  "date": "$DATE",
  "timestamp": "$TIMESTAMP",
  "duration_seconds": $DURATION,
  "tasks_total": $TOTAL,
  "tasks_done": $DONE,
  "tasks_failed": $FAILED,
  "error_count": $ERRORS,
  "commit_count": $COMMITS,
  "successes": $SUCCESSES
}
EOF
