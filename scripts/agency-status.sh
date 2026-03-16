#!/bin/bash
#
# agency-status.sh — Show running agent sessions
# Usage: agency status

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/env.sh"
source "$SCRIPT_DIR/agency-ui-utils.sh"

echo ""
echo "Agency OS — Active Sessions"
echo ""

if ! command -v zellij &>/dev/null; then
  echo "  Zellij not installed. No sessions to show."
  exit 0
fi

# List Zellij sessions
SESSIONS=$(zellij list-sessions 2>/dev/null | sed $'s/\033\[[0-9;]*m//g' || echo "")
if [[ -z "$SESSIONS" ]]; then
  echo "  No Zellij sessions running."
  exit 0
fi

AGENCY_COUNT=0
while IFS= read -r line; do
  [[ "$line" == *"EXITED"* ]] && continue
  session_name=$(echo "$line" | awk '{print $1}')

  if [[ "$session_name" == agency-* ]]; then
    ((AGENCY_COUNT++))
    echo -e "  ${UI_GREEN}${session_name}${UI_NC}"

    # Show live project statuses
    for project_dir in "$AGENCY_LIVE_DIR"/*/; do
      [[ ! -d "$project_dir" ]] && continue
      name=$(basename "$project_dir")
      status=$(cat "$project_dir/orchestrator.status" 2>/dev/null || echo "unknown")
      total=$(count_total_tasks "$project_dir/tasks")
      done_count=$(count_by_status "$project_dir/tasks" "done")
      done_count2=$(count_by_status "$project_dir/tasks" "completed")
      done_total=$((done_count + done_count2))
      elapsed=$(get_session_elapsed "$project_dir")
      elapsed_fmt=$(format_elapsed "$elapsed")

      # Status color
      case "$status" in
        running)   color="$UI_BLUE" ;;
        completed) color="$UI_GREEN" ;;
        failed)    color="$UI_RED" ;;
        qa)        color="$UI_YELLOW" ;;
        *)         color="$UI_DIM" ;;
      esac

      bar=$(draw_progress_bar "$done_total" "$total" 15)
      echo -e "    ${color}[$status]${UI_NC} $name  $bar  ${UI_DIM}${elapsed_fmt}${UI_NC}"
    done
    echo ""
  fi
done <<< "$SESSIONS"

if [[ "$AGENCY_COUNT" -eq 0 ]]; then
  echo "  No agency sessions running."
  echo ""
  echo "  Other Zellij sessions:"
  echo "$SESSIONS" | grep -v EXITED | awk '{print "    " $1}' || true
fi

echo ""
