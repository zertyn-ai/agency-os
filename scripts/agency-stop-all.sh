#!/bin/bash
#
# agency-stop-all.sh — Global kill switch
#
# Kills all Zellij agent sessions, prunes worktrees.
# Usage: agency-stop-all.sh ["reason"]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/env.sh"

REASON="${1:-manual stop}"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "[$TIMESTAMP] Stopping all agents... Reason: $REASON"

# Kill Zellij agency sessions
if command -v zellij &>/dev/null; then
  SESSIONS=$(zellij list-sessions 2>/dev/null | sed $'s/\033\[[0-9;]*m//g' | grep -v EXITED | grep "^agency-" | awk '{print $1}' || echo "")
  if [[ -n "$SESSIONS" ]]; then
    while IFS= read -r session; do
      zellij kill-session "$session" 2>/dev/null || true
      echo "  Killed: $session"
    done <<< "$SESSIONS"
  else
    echo "  No active Zellij agency sessions found"
  fi
else
  echo "  Zellij not found"
fi

# Prune worktrees in all known projects
if [ -f "$AGENCY_DIR/projects.yaml" ]; then
  grep "path:" "$AGENCY_DIR/projects.yaml" 2>/dev/null | sed 's/.*path:\s*"\?\([^"]*\)"\?.*/\1/' | while read -r path; do
    path="${path/#\~/$HOME}"
    [ -d "$path/.git" ] && git -C "$path" worktree prune 2>/dev/null && echo "  Pruned worktrees: $path"
  done
fi

echo "[$TIMESTAMP] All agents stopped."
