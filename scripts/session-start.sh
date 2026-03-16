#!/bin/bash
#
# session-start.sh — Output session context to stdout for Claude injection.
#
# Three layers of context:
#   Layer 1: Git-based (always available)
#   Layer 2: Handoff-based (available after Claude sessions)
#   Layer 3: Plan-day (available when a daily plan exists for today)
#
# Designed for Claude Code onSessionStart hook.
# Compact output (~200-400 tokens).

set -uo pipefail

# Must be in a git repo
if [[ ! -d ".git" ]]; then
  exit 0
fi

# Resolve AGENCY_DIR from hook symlink or env
if [[ -n "${AGENCY_DIR:-}" ]]; then
  : # already set
elif [[ -L "${BASH_SOURCE[0]}" ]]; then
  AGENCY_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.." && pwd)"
else
  AGENCY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

PROJECT_NAME=$(basename "$(pwd)")
DATE=$(date +%Y-%m-%d)

OUTPUT=""

# === Layer 0: Agency OS Status Line ===
RULES_COUNT=$(ls "$AGENCY_DIR/rules/"*.md 2>/dev/null | wc -l | tr -d ' ')
HOOKS_COUNT=$(ls "$AGENCY_DIR/hooks/"*.sh 2>/dev/null | wc -l | tr -d ' ')
CODEX_STATUS="missing"
[[ -f "$(pwd)/project-codex.yaml" ]] && CODEX_STATUS="loaded"
ROLES_PATH="$(realpath "$AGENCY_DIR/roles" 2>/dev/null || echo "$AGENCY_DIR/roles")"

OUTPUT+="Agency OS: ${RULES_COUNT} rules | ${HOOKS_COUNT} hooks | codex ${CODEX_STATUS} | roles at ${ROLES_PATH}
"

# === Layer 1: Git-based context ===
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
RECENT_COMMITS=$(git log --oneline -5 2>/dev/null || echo "(no commits)")
UNCOMMITTED=""
if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
  UNCOMMITTED=$(git status --short 2>/dev/null | head -10)
fi

OUTPUT+="## Session Briefing: $PROJECT_NAME
Branch: $BRANCH

Recent commits:
$RECENT_COMMITS
"

if [[ -n "$UNCOMMITTED" ]]; then
  OUTPUT+="
Uncommitted changes:
$UNCOMMITTED
"
fi

# Open PRs (non-blocking, max 3)
if command -v gh &>/dev/null; then
  OPEN_PRS=$(gh pr list --state open --limit 3 2>/dev/null || echo "")
  if [[ -n "$OPEN_PRS" ]]; then
    OUTPUT+="
Open PRs:
$OPEN_PRS
"
  fi
fi

# === Layer 1.5: Project Codex ===
CODEX_FILE="$(pwd)/project-codex.yaml"
if [[ -f "$CODEX_FILE" ]]; then
  OUTPUT+="
---
## Project Codex
$(cat "$CODEX_FILE" 2>/dev/null)
"
fi

# === Layer 2: Handoff from previous session ===
HANDOFF_FILE="$AGENCY_DIR/handoffs/$PROJECT_NAME.md"
if [[ -f "$HANDOFF_FILE" ]]; then
  HANDOFF=$(cat "$HANDOFF_FILE" 2>/dev/null || echo "")
  if [[ -n "$HANDOFF" ]]; then
    OUTPUT+="
---
## Previous Session Handoff
$HANDOFF
"
  fi
fi

# === Layer 3: Today's plan ===
PLAN_FILE="$AGENCY_DIR/daily-plan.yaml"
if [[ -f "$PLAN_FILE" ]]; then
  if grep -q "date:.*$DATE" "$PLAN_FILE" 2>/dev/null; then
    PLAN_TASKS=$(awk -v proj="$PROJECT_NAME" '
      /name:/ && $0 ~ proj { found=1; next }
      found && /tasks:/ { intasks=1; next }
      found && intasks && /^    - / { print $0 }
      found && intasks && /^  - name:/ { exit }
      found && intasks && /^[^ ]/ { exit }
    ' "$PLAN_FILE" 2>/dev/null)

    if [[ -n "$PLAN_TASKS" ]]; then
      OUTPUT+="
---
## Today's Plan Tasks
$PLAN_TASKS
"
    fi
  fi
fi

# Output
echo "$OUTPUT"
