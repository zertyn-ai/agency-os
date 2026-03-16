#!/bin/bash
#
# pre-compact.sh — PreCompact hook
# Writes structured checkpoint YAML before context compaction.
# Reads task state from SESSION_DIR (live/{project}/tasks/).

set -uo pipefail

AGENCY_DIR="${AGENCY_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT_NAME=$(basename "$(pwd)" 2>/dev/null || echo "unknown")
SESSION_DIR="$AGENCY_DIR/live/$PROJECT_NAME"
CHECKPOINT_FILE="$SESSION_DIR/compact-checkpoint.yaml"

# Skip if no live session
[ ! -d "$SESSION_DIR/tasks" ] && exit 0

# Collect task states
COMPLETED=""
PENDING=""
CURRENT=""
LAST_ERROR=""

for status_file in "$SESSION_DIR/tasks"/*.status; do
  [ -f "$status_file" ] || continue
  tid=$(basename "$status_file" .status)
  status=$(cat "$status_file" 2>/dev/null || echo "unknown")
  case "$status" in
    done|completed) COMPLETED="${COMPLETED:+$COMPLETED, }$tid" ;;
    running)        CURRENT="$tid" ;;
    failed)         LAST_ERROR="$tid" ;;
    *)              PENDING="${PENDING:+$PENDING, }$tid" ;;
  esac
done

# Get last error detail
ERROR_DETAIL=""
if [ -n "$LAST_ERROR" ] && [ -f "$SESSION_DIR/tasks/$LAST_ERROR.detail" ]; then
  ERROR_DETAIL=$(cat "$SESSION_DIR/tasks/$LAST_ERROR.detail" 2>/dev/null | head -1)
fi

# Get modified files from git
MODIFIED_FILES=$(git diff --name-only HEAD~3 2>/dev/null | head -10 | tr '\n' ', ' | sed 's/,$//')

# Get current activity
ACTIVITY=""
if [ -n "$CURRENT" ] && [ -f "$SESSION_DIR/tasks/$CURRENT.activity" ]; then
  ACTIVITY=$(cat "$SESSION_DIR/tasks/$CURRENT.activity" 2>/dev/null | head -1)
fi

# Write checkpoint
cat > "$CHECKPOINT_FILE" << EOF
current_task: ${CURRENT:-null}
completed_tasks: [${COMPLETED:-}]
pending_tasks: [${PENDING:-}]
modified_files: [${MODIFIED_FILES:-}]
last_error: ${ERROR_DETAIL:-null}
activity: "${ACTIVITY:-unknown}"
EOF
