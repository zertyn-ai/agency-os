#!/bin/bash
#
# agency-update.sh — Pull latest changes and refresh symlinks
# Usage: agency update

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/env.sh"

echo ""
echo "Agency OS — Update"
echo ""

cd "$AGENCY_DIR"

# Check for local modifications
LOCAL_MODS=$(git status --porcelain 2>/dev/null || echo "")
STASHED=false

if [[ -n "$LOCAL_MODS" ]]; then
  echo "  Local modifications detected:"
  echo "$LOCAL_MODS" | head -5 | sed 's/^/    /'
  echo ""
  echo "  Stashing changes before pull..."
  git stash push -m "agency-update-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || {
    echo "  ERROR: Failed to stash changes. Aborting update."
    echo "  Please commit or stash your changes manually."
    exit 1
  }
  STASHED=true
fi

# Pull latest
echo "  Pulling latest..."
if git pull --rebase 2>/dev/null; then
  echo "  + Pull successful"
else
  echo "  ERROR: Pull failed."
  if [[ "$STASHED" == true ]]; then
    echo "  Restoring stashed changes..."
    git stash pop 2>/dev/null || true
  fi
  exit 1
fi

# Restore stashed changes
if [[ "$STASHED" == true ]]; then
  echo "  Restoring local changes..."
  if git stash pop 2>/dev/null; then
    echo "  + Changes restored"
  else
    echo ""
    echo "  WARNING: Merge conflict restoring local changes."
    echo "  Your changes are in git stash. Resolve with:"
    echo "    cd $AGENCY_DIR"
    echo "    git stash show -p"
    echo "    git stash pop"
    echo ""
    echo "  Continuing with symlink refresh..."
  fi
fi

# Always refresh symlinks
echo ""
echo "  Refreshing symlinks..."

# Commands
mkdir -p "$HOME/.claude/commands"
for cmd_file in "$AGENCY_DIR/commands/"*.md; do
  [[ ! -f "$cmd_file" ]] && continue
  name=$(basename "$cmd_file")
  target="$HOME/.claude/commands/$name"
  if [[ -L "$target" ]]; then
    # Already a symlink — update if target changed
    current=$(readlink "$target" 2>/dev/null || echo "")
    if [[ "$current" != "$cmd_file" ]]; then
      ln -sf "$cmd_file" "$target"
      echo "    Updated: $name"
    fi
  elif [[ -f "$target" ]]; then
    # Regular file exists — skip (user's own file)
    echo "    Skipped: $name (user file exists)"
  else
    ln -s "$cmd_file" "$target"
    echo "    Linked: $name"
  fi
done

# Rules
mkdir -p "$HOME/.claude/rules"
for rule_file in "$AGENCY_DIR/rules/"*.md; do
  [[ ! -f "$rule_file" ]] && continue
  name=$(basename "$rule_file")
  target="$HOME/.claude/rules/$name"
  if [[ -L "$target" ]]; then
    current=$(readlink "$target" 2>/dev/null || echo "")
    if [[ "$current" != "$rule_file" ]]; then
      ln -sf "$rule_file" "$target"
    fi
  elif [[ -f "$target" ]]; then
    echo "    Skipped rule: $name (user file exists)"
  else
    ln -s "$rule_file" "$target"
  fi
done

echo "  + Symlinks refreshed"
echo ""
echo "Agency OS updated successfully."
echo ""
