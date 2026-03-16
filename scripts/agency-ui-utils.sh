#!/bin/bash
#
# agency-ui-utils.sh
# Shared UI utility functions for watcher and scripts.
# Source this file: source "$AGENCY_DIR/scripts/agency-ui-utils.sh"

# Colors
UI_GREEN='\033[0;32m'
UI_BLUE='\033[0;34m'
UI_YELLOW='\033[1;33m'
UI_RED='\033[0;31m'
UI_CYAN='\033[0;36m'
UI_DIM='\033[2m'
UI_BOLD='\033[1m'
UI_NC='\033[0m'
UI_WHITE='\033[1;37m'
UI_MAGENTA='\033[0;35m'

# Converts seconds to human-readable "Xm Ys" or "Xh Ym"
format_elapsed() {
  local secs=${1:-0}
  if [[ "$secs" -lt 60 ]]; then
    echo "${secs}s"
  elif [[ "$secs" -lt 3600 ]]; then
    local mins=$((secs / 60))
    local remaining=$((secs % 60))
    echo "${mins}m ${remaining}s"
  else
    local hours=$((secs / 3600))
    local mins=$(( (secs % 3600) / 60 ))
    echo "${hours}h ${mins}m"
  fi
}

# Renders a progress bar with percentage
draw_progress_bar() {
  local done=${1:-0}
  local total=${2:-1}
  local width=${3:-20}

  if [[ "$total" -eq 0 ]]; then total=1; fi

  local pct=$((done * 100 / total))
  local filled=$((done * width / total))
  local empty=$((width - filled))

  local bar=""
  for ((i = 0; i < filled; i++)); do bar+="█"; done
  for ((i = 0; i < empty; i++)); do bar+="░"; done

  echo "${bar}  ${pct}%"
}

# Counts task files matching a given status value
count_by_status() {
  local tasks_dir="$1"
  local target_status="$2"
  local count=0

  if [[ ! -d "$tasks_dir" ]]; then echo "0"; return; fi

  for status_file in "$tasks_dir"/*.status; do
    [[ ! -f "$status_file" ]] && continue
    local status
    status=$(cat "$status_file" 2>/dev/null || echo "")
    [[ "$status" == "$target_status" ]] && ((count++))
  done

  echo "$count"
}

# Counts total task status files
count_total_tasks() {
  local tasks_dir="$1"
  local count=0

  if [[ ! -d "$tasks_dir" ]]; then echo "0"; return; fi

  for status_file in "$tasks_dir"/*.status; do
    [[ ! -f "$status_file" ]] && continue
    ((count++))
  done

  echo "$count"
}

# Returns elapsed seconds since session start
get_session_elapsed() {
  local session_dir="$1"
  if [[ -f "$session_dir/session.started_at" ]]; then
    local started
    started=$(cat "$session_dir/session.started_at" 2>/dev/null || echo "0")
    echo $(( $(date +%s) - started ))
  else
    echo "0"
  fi
}

# Returns elapsed seconds for a specific task
get_task_elapsed() {
  local tasks_dir="$1"
  local task_id="$2"

  if [[ -f "$tasks_dir/$task_id.completed_at" ]]; then
    local started completed
    started=$(cat "$tasks_dir/$task_id.started_at" 2>/dev/null || echo "0")
    completed=$(cat "$tasks_dir/$task_id.completed_at" 2>/dev/null || echo "0")
    echo $((completed - started))
  elif [[ -f "$tasks_dir/$task_id.started_at" ]]; then
    local started
    started=$(cat "$tasks_dir/$task_id.started_at" 2>/dev/null || echo "0")
    echo $(( $(date +%s) - started ))
  else
    echo "0"
  fi
}
