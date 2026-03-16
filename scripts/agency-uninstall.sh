#!/bin/bash
#
# agency-uninstall.sh — Remove Agency OS hooks, symlinks, and PATH entry
# Usage: agency uninstall

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENCY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo ""
echo "Agency OS — Uninstall"
echo ""

# 1. Remove command symlinks
echo "  Removing command symlinks..."
for cmd_file in "$AGENCY_DIR/commands/"*.md; do
  [[ ! -f "$cmd_file" ]] && continue
  name=$(basename "$cmd_file")
  target="$HOME/.claude/commands/$name"
  if [[ -L "$target" ]]; then
    link_target=$(readlink "$target" 2>/dev/null || echo "")
    if [[ "$link_target" == "$AGENCY_DIR/"* || "$link_target" == *"/agency-os/"* ]]; then
      rm -f "$target"
      echo "    Removed: $name"
    fi
  fi
done

# 2. Remove rule symlinks
echo "  Removing rule symlinks..."
for rule_file in "$AGENCY_DIR/rules/"*.md; do
  [[ ! -f "$rule_file" ]] && continue
  name=$(basename "$rule_file")
  target="$HOME/.claude/rules/$name"
  if [[ -L "$target" ]]; then
    link_target=$(readlink "$target" 2>/dev/null || echo "")
    if [[ "$link_target" == "$AGENCY_DIR/"* || "$link_target" == *"/agency-os/"* ]]; then
      rm -f "$target"
      echo "    Removed: $name"
    fi
  fi
done

# 3. Remove hooks from settings.json
SETTINGS_FILE="$HOME/.claude/settings.json"
if [[ -f "$SETTINGS_FILE" ]] && command -v jq &>/dev/null; then
  echo "  Removing hooks from settings.json..."
  # Remove any hooks that reference agency-os or AGENCY_DIR
  TEMP_SETTINGS=$(mktemp)
  jq --arg dir "$AGENCY_DIR" '
    if .hooks then
      .hooks |= with_entries(
        .value |= (if type == "array" then
          map(select(
            (if type == "object" then .command else . end) |
            tostring | (contains($dir) or contains("agency-os")) | not
          ))
        else . end)
      )
    else . end
  ' "$SETTINGS_FILE" > "$TEMP_SETTINGS" 2>/dev/null

  if [[ -s "$TEMP_SETTINGS" ]]; then
    mv "$TEMP_SETTINGS" "$SETTINGS_FILE"
    echo "    + Hooks removed from settings.json"
  else
    rm -f "$TEMP_SETTINGS"
    echo "    Could not update settings.json (manual cleanup may be needed)"
  fi
fi

# 4. Remove PATH entry
echo "  Checking PATH..."
for rc_file in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile" "$HOME/.bash_profile"; do
  if [[ -f "$rc_file" ]] && grep -q "agency-os" "$rc_file" 2>/dev/null; then
    # Create backup
    cp "$rc_file" "${rc_file}.bak"
    grep -v "agency-os" "$rc_file" > "${rc_file}.tmp" && mv "${rc_file}.tmp" "$rc_file"
    echo "    Removed PATH entry from $(basename "$rc_file")"
  fi
done

echo ""
echo "Agency OS uninstalled."
echo ""
echo "  Symlinks, hooks, and PATH entry removed."
echo "  The directory $AGENCY_DIR was NOT deleted."
echo "  To fully remove: rm -rf $AGENCY_DIR"
echo ""
