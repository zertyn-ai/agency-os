#!/usr/bin/env bash
#
# env.sh — The foundation. Every script sources this.
# All identity, paths, and config flow through here.

AGENCY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load config (created by setup.sh) — validate syntax first
if [[ -f "$AGENCY_DIR/config" ]]; then
  if bash -n "$AGENCY_DIR/config" 2>/dev/null; then
    source "$AGENCY_DIR/config"
  else
    echo "WARNING: $AGENCY_DIR/config has syntax errors. Using defaults." >&2
  fi
fi

# Auto-detect anything not in config
AGENCY_PROFILE="${AGENCY_PROFILE:-production}"
AGENCY_GH_USER="${AGENCY_GH_USER:-$(gh api user --jq '.login' 2>/dev/null || git config user.name 2>/dev/null || echo "")}"
AGENCY_GH_ORG="${AGENCY_GH_ORG:-$AGENCY_GH_USER}"

# Supports colon-separated paths: "$HOME/work:$HOME/personal"
AGENCY_PROJECTS_DIR="${AGENCY_PROJECTS_DIR:-$HOME/projects}"
AGENCY_PERMISSIONS_MODE="${AGENCY_PERMISSIONS_MODE:-standard}"  # "standard" or "yolo"

# Zellij required for dispatch
if ! command -v zellij &>/dev/null; then
  AGENCY_ZELLIJ_MISSING=true
fi
AGENCY_MUX="zellij"

# Derived paths
AGENCY_ROLES_DIR="$AGENCY_DIR/roles"
AGENCY_SCRIPTS_DIR="$AGENCY_DIR/scripts"
AGENCY_HOOKS_DIR="$AGENCY_DIR/hooks"
AGENCY_COMMANDS_DIR="$AGENCY_DIR/commands"
AGENCY_HANDOFFS_DIR="$AGENCY_DIR/handoffs"
AGENCY_LIVE_DIR="$AGENCY_DIR/live"
AGENCY_METRICS_DIR="$AGENCY_DIR/metrics"

export AGENCY_DIR AGENCY_PROFILE AGENCY_GH_USER AGENCY_GH_ORG
export AGENCY_PROJECTS_DIR AGENCY_MUX AGENCY_PERMISSIONS_MODE
export AGENCY_ROLES_DIR AGENCY_SCRIPTS_DIR AGENCY_HOOKS_DIR AGENCY_COMMANDS_DIR
export AGENCY_HANDOFFS_DIR AGENCY_LIVE_DIR AGENCY_METRICS_DIR
