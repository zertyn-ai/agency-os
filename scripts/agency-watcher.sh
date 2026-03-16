#!/bin/bash
#
# agency-watcher.sh — Live progress dashboard for Zellij first pane.
#
# Reads live/{project}/status and activity.log files.
# Shows real-time agent progress + completion summary with PR links.
# Detects stalled (>10 min no activity) and crashed (pane gone) sessions.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/env.sh"
source "$SCRIPT_DIR/agency-ui-utils.sh"

LIVE_DIR="$AGENCY_LIVE_DIR"
POLL_INTERVAL=2
STALE_THRESHOLD=600  # 10 minutes

# ─── Header ───
print_header() {
  local date_str
  date_str=$(date '+%Y-%m-%d %H:%M')
  echo -e "${UI_CYAN}╔═══════════════════════════════════════════════╗${UI_NC}"
  echo -e "${UI_CYAN}║          Agency OS — Live Watcher              ║${UI_NC}"
  echo -e "${UI_CYAN}║          $date_str                        ║${UI_NC}"
  echo -e "${UI_CYAN}╚═══════════════════════════════════════════════╝${UI_NC}"
  echo ""
}

# ─── Check if a Zellij pane/tab for a project still exists ───
pane_exists() {
  local project_name=$1
  # Check if a tab with this name exists in current session
  zellij action query-tab-names 2>/dev/null | grep -qi "$project_name" 2>/dev/null
}

# ─── Get last activity time ───
get_last_activity() {
  local session_dir=$1
  local log_file="$session_dir/activity.log"
  if [[ -f "$log_file" ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then
      stat -f %m "$log_file" 2>/dev/null || echo "0"
    else
      stat -c %Y "$log_file" 2>/dev/null || echo "0"
    fi
  else
    echo "0"
  fi
}

# ─── Render project status ───
render_project() {
  local name=$1
  local session_dir="$LIVE_DIR/$name"

  local status
  status=$(cat "$session_dir/orchestrator.status" 2>/dev/null || echo "unknown")

  local total done_count done2 failed running
  total=$(count_total_tasks "$session_dir/tasks")
  done_count=$(count_by_status "$session_dir/tasks" "done")
  done2=$(count_by_status "$session_dir/tasks" "completed")
  failed=$(count_by_status "$session_dir/tasks" "failed")
  running=$(count_by_status "$session_dir/tasks" "running")
  local done_total=$((done_count + done2))

  local elapsed elapsed_fmt
  elapsed=$(get_session_elapsed "$session_dir")
  elapsed_fmt=$(format_elapsed "$elapsed")

  # Detect stalled/crashed
  local now
  now=$(date +%s)
  local last_activity
  last_activity=$(get_last_activity "$session_dir")
  local activity_age=$((now - last_activity))

  if [[ "$status" == "running" || "$status" == "qa" ]]; then
    if [[ "$activity_age" -gt "$STALE_THRESHOLD" ]]; then
      # Check if pane still exists
      if ! pane_exists "$name"; then
        status="crashed"
      else
        status="stalled"
      fi
    fi
  fi

  # Status color
  local color icon
  case "$status" in
    running)   color="$UI_BLUE";    icon=">" ;;
    completed) color="$UI_GREEN";   icon="+" ;;
    failed)    color="$UI_RED";     icon="x" ;;
    qa)        color="$UI_YELLOW";  icon="?" ;;
    stalled)   color="$UI_YELLOW";  icon="!" ;;
    crashed)   color="$UI_RED";     icon="!" ;;
    waiting)   color="$UI_DIM";     icon="." ;;
    *)         color="$UI_DIM";     icon="." ;;
  esac

  # Progress bar
  local bar
  bar=$(draw_progress_bar "$done_total" "$total" 20)

  # Current action
  local current_action=""
  local current_task
  current_task=$(cat "$session_dir/orchestrator.current" 2>/dev/null || echo "")
  if [[ -n "$current_task" ]]; then
    current_action="$current_task"
  fi

  # Last activity log line
  local last_log=""
  if [[ -f "$session_dir/activity.log" ]]; then
    last_log=$(tail -1 "$session_dir/activity.log" 2>/dev/null | head -c 60 || echo "")
  fi

  # Needs input?
  local input_flag=""
  if [[ -f "$session_dir/needs-input" ]]; then
    input_flag=" ${UI_RED}[NEEDS INPUT]${UI_NC}"
  fi

  echo -e "  ${color}[$icon]${UI_NC} ${UI_BOLD}$name${UI_NC}  $bar  ${UI_DIM}${elapsed_fmt}${UI_NC}${input_flag}"

  if [[ "$status" == "stalled" ]]; then
    local stale_mins=$((activity_age / 60))
    echo -e "      ${UI_YELLOW}No activity for ${stale_mins}m${UI_NC}"
  elif [[ "$status" == "crashed" ]]; then
    echo -e "      ${UI_RED}Zellij pane not found — session may have crashed${UI_NC}"
  fi

  if [[ -n "$current_action" && "$status" != "completed" ]]; then
    echo -e "      ${UI_DIM}$current_action${UI_NC}"
  fi

  if [[ "$failed" -gt 0 ]]; then
    echo -e "      ${UI_RED}$failed task(s) failed${UI_NC}"
  fi
}

# ─── Completion summary ───
print_completion_summary() {
  echo ""
  echo -e "${UI_GREEN}═══ Completion Summary ═══${UI_NC}"
  echo ""

  for project_dir in "$LIVE_DIR"/*/; do
    [[ ! -d "$project_dir" ]] && continue
    local name
    name=$(basename "$project_dir")
    local status
    status=$(cat "$project_dir/orchestrator.status" 2>/dev/null || echo "unknown")

    if [[ "$status" == "completed" ]]; then
      echo -e "  ${UI_GREEN}+${UI_NC} $name"

      # Check for PRs
      local project_path
      project_path=$(yq ".projects[] | select(.name == \"$name\") | .path" "$AGENCY_DIR/daily-plan.yaml" 2>/dev/null || echo "")
      project_path="${project_path/#\~/$HOME}"

      if [[ -n "$project_path" && -d "$project_path" ]]; then
        local prs
        prs=$(cd "$project_path" && gh pr list --state open --limit 5 --json number,title,url --jq '.[] | "    PR #\(.number): \(.title) → \(.url)"' 2>/dev/null || echo "")
        if [[ -n "$prs" ]]; then
          echo "$prs"
        fi
      fi
    fi
  done
}

# ─── Main loop ───
main() {
  # Wait for live dir to appear
  while [[ ! -d "$LIVE_DIR" ]] || [[ -z "$(ls -A "$LIVE_DIR" 2>/dev/null)" ]]; do
    clear
    print_header
    echo -e "  ${UI_DIM}Waiting for dispatch to prepare sessions...${UI_NC}"
    sleep "$POLL_INTERVAL"
  done

  while true; do
    clear
    print_header

    local all_completed=true
    local any_project=false

    for project_dir in "$LIVE_DIR"/*/; do
      [[ ! -d "$project_dir" ]] && continue
      [[ "$(basename "$project_dir")" == "_ralph" ]] && continue
      any_project=true

      local name
      name=$(basename "$project_dir")
      render_project "$name"
      echo ""

      local status
      status=$(cat "$project_dir/orchestrator.status" 2>/dev/null || echo "unknown")
      if [[ "$status" != "completed" && "$status" != "failed" ]]; then
        all_completed=false
      fi
    done

    if [[ "$any_project" == false ]]; then
      echo -e "  ${UI_DIM}No active sessions.${UI_NC}"
    fi

    # Show completion summary if all done
    if [[ "$all_completed" == true && "$any_project" == true ]]; then
      print_completion_summary
      echo ""
      echo -e "${UI_GREEN}All sessions complete. Press Ctrl+C to exit.${UI_NC}"
      # Keep refreshing but slower
      sleep 10
    else
      sleep "$POLL_INTERVAL"
    fi
  done
}

main
