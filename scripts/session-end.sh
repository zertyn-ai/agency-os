#!/bin/bash
#
# session-end.sh — Generate handoff file for the current project.
#
# Creates handoffs/{PROJECT}.md with a structured snapshot of
# the session state: git info, task statuses, errors, and decisions.
#
# Designed for Claude Code onSessionEnd hook.
# Fast (< 2s), no Claude calls, graceful degradation.

set -uo pipefail

# Must be in a git repo
if [[ ! -d ".git" ]]; then
  exit 0
fi

# Resolve AGENCY_DIR
if [[ -n "${AGENCY_DIR:-}" ]]; then
  : # already set
elif [[ -L "${BASH_SOURCE[0]}" ]]; then
  AGENCY_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.." && pwd)"
else
  AGENCY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

PROJECT_NAME=$(basename "$(pwd)")
HANDOFF_DIR="$AGENCY_DIR/handoffs"
HANDOFF_FILE="$HANDOFF_DIR/$PROJECT_NAME.md"
LIVE_DIR="$AGENCY_DIR/live/$PROJECT_NAME"
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')

mkdir -p "$HANDOFF_DIR"

# Session duration
DURATION="unknown"
if [[ -f "$LIVE_DIR/session.started_at" ]]; then
  STARTED_AT=$(cat "$LIVE_DIR/session.started_at" 2>/dev/null || echo "")
  if [[ -n "$STARTED_AT" ]]; then
    NOW=$(date +%s)
    ELAPSED=$(( NOW - STARTED_AT ))
    MINUTES=$(( ELAPSED / 60 ))
    DURATION="${MINUTES}m"
  fi
fi

# Git state
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
LAST_COMMIT=$(git log --oneline -1 2>/dev/null || echo "(no commits)")
UNCOMMITTED="no"
if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
  UNCOMMITTED="yes"
fi

# Today's commits
TODAYS_COMMITS=$(git log --since="6am today" --oneline 2>/dev/null || echo "(none)")
if [[ -z "$TODAYS_COMMITS" ]]; then
  TODAYS_COMMITS="(none)"
fi

# Open PRs (non-blocking)
OPEN_PRS="(unable to fetch)"
if command -v gh &>/dev/null; then
  OPEN_PRS=$(gh pr list --state open --limit 5 2>/dev/null || echo "(unable to fetch)")
fi
if [[ -z "$OPEN_PRS" ]]; then
  OPEN_PRS="(none)"
fi

# Task statuses from live/
TASKS_COMPLETED=""
TASKS_FAILED=""
TASKS_REMAINING=""

if [[ -d "$LIVE_DIR/tasks" ]]; then
  for task_file in "$LIVE_DIR/tasks"/*.status; do
    [[ -f "$task_file" ]] || continue
    task_id=$(basename "$task_file" .status)
    status=$(cat "$task_file" 2>/dev/null || echo "unknown")
    case "$status" in
      completed|done)
        TASKS_COMPLETED+="- $task_id: completed
"
        ;;
      failed|error)
        TASKS_FAILED+="- $task_id: failed
"
        ;;
      *)
        TASKS_REMAINING+="- $task_id [$status]
"
        ;;
    esac
  done
fi

[[ -z "$TASKS_COMPLETED" ]] && TASKS_COMPLETED="(none)
"
[[ -z "$TASKS_FAILED" ]] && TASKS_FAILED="(none)
"
[[ -z "$TASKS_REMAINING" ]] && TASKS_REMAINING="(none)
"

# Errors (last 10 lines from error.log)
ERRORS="(none)"
if [[ -f "$LIVE_DIR/error.log" && -s "$LIVE_DIR/error.log" ]]; then
  ERRORS=$(tail -10 "$LIVE_DIR/error.log" 2>/dev/null || echo "(unable to read)")
fi

# Write handoff file
cat > "$HANDOFF_FILE" << EOF
# Session Handoff: $PROJECT_NAME
# Generated: $TIMESTAMP | Duration: $DURATION

## Last Session Summary
Commits today:
$TODAYS_COMMITS

## Tasks Completed
$TASKS_COMPLETED
## Tasks Failed
$TASKS_FAILED
## Tasks Remaining
$TASKS_REMAINING
## Current State
- Branch: $BRANCH
- Last commit: $LAST_COMMIT
- Uncommitted: $UNCOMMITTED
- Open PRs: $OPEN_PRS

## Errors
$ERRORS
EOF

# Codex: init or update
PROJECT_ROOT="$(pwd)"
CODEX_FILE="$PROJECT_ROOT/project-codex.yaml"

if [[ ! -f "$CODEX_FILE" ]]; then
  if [[ -x "$AGENCY_DIR/scripts/agency-codex-init.sh" ]]; then
    bash "$AGENCY_DIR/scripts/agency-codex-init.sh" "$PROJECT_ROOT" 2>/dev/null || true
  fi
elif [[ -x "$AGENCY_DIR/scripts/agency-quality-snapshot.sh" ]]; then
  SNAPSHOT=$(bash "$AGENCY_DIR/scripts/agency-quality-snapshot.sh" "$PROJECT_ROOT" 2>/dev/null || echo "{}")
  SCAN_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  extract_val() {
    echo "$SNAPSHOT" | grep "\"$1\"" 2>/dev/null | head -1 | sed 's/.*: *\([0-9.]*\).*/\1/' || echo "0"
  }

  TC=$(extract_val "test_count")
  TP=$(extract_val "test_pass_count")
  TE=$(extract_val "type_error_count")
  TC=${TC:-0}; TP=${TP:-0}; TE=${TE:-0}

  PASS_RATE="0.00"
  if [[ "$TC" -gt 0 ]] 2>/dev/null; then
    PASS_RATE=$(awk "BEGIN {printf \"%.2f\", $TP / $TC}")
  fi

  if grep -q "last_scan:" "$CODEX_FILE" 2>/dev/null; then
    sed -i.bak \
      -e "s|last_scan:.*|last_scan: \"$SCAN_TIME\"|" \
      -e "s|test_count:.*|test_count: $TC|" \
      -e "s|test_pass_rate:.*|test_pass_rate: $PASS_RATE|" \
      -e "s|type_errors:.*|type_errors: $TE|" \
      "$CODEX_FILE" 2>/dev/null || true
    rm -f "${CODEX_FILE}.bak"
  fi

  if [[ -f "$LIVE_DIR/error.log" && -s "$LIVE_DIR/error.log" ]]; then
    while IFS= read -r err_line; do
      clean=$(echo "$err_line" | sed 's/^\[.*\] //' | sed 's/"/\\"/g' | head -c 200)
      if [[ -n "$clean" ]] && ! grep -qF "$clean" "$CODEX_FILE" 2>/dev/null; then
        sed -i.bak "/^failed_approaches:/a\\  - \"$clean\"" "$CODEX_FILE" 2>/dev/null || true
        rm -f "${CODEX_FILE}.bak"
      fi
    done < <(tail -5 "$LIVE_DIR/error.log" 2>/dev/null | sort -u)
  fi
fi
