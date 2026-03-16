#!/bin/bash
#
# agency-preflight.sh — Pre-flight checks (agency doctor)
#
# Validates environment health before launching agents.
# Usage: agency doctor [project-path]
# Exit: 0 = all checks pass, 1 = one or more failed

set -uo pipefail

# Source env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/env.sh"

PROJECT_PATH="${1:-.}"
FAILED=0

check() {
  local name="$1" result="$2"
  if [ "$result" -eq 0 ]; then
    echo "  + $name"
  else
    echo "  x $name"
    FAILED=$((FAILED + 1))
  fi
}

echo "Agency OS — Pre-flight checks"
echo ""

# 1. Required tools
for tool in claude yq jq gh zellij; do
  command -v "$tool" &>/dev/null
  check "$tool installed" $?
done

# 2. yq is the right version (mikefarah Go version)
if command -v yq &>/dev/null; then
  yq --version 2>&1 | grep -q "mikefarah"
  check "yq is mikefarah/yq (Go version)" $?
fi

# 3. GitHub auth
if command -v gh &>/dev/null; then
  gh auth status &>/dev/null
  check "GitHub authenticated (gh auth status)" $?
fi

# 4. Git config
GIT_USER=$(git config user.name 2>/dev/null || echo "")
[ -n "$GIT_USER" ]
check "Git user configured ($GIT_USER)" $?

# 5. Disk space > 2GB
AVAIL_KB=$(df -k "$PROJECT_PATH" 2>/dev/null | tail -1 | awk '{print $4}')
AVAIL_KB=${AVAIL_KB:-0}
[ "$AVAIL_KB" -gt 2097152 ] 2>/dev/null
check "Disk space > 2GB ($(( AVAIL_KB / 1048576 ))GB available)" $?

# 6. Zellij not nested
if [[ -z "${ZELLIJ:-}" ]]; then
  check "Not inside Zellij (safe for dispatch)" 0
else
  check "Not inside Zellij (dispatch will append tabs)" 1
fi

# 7. Config file valid
if [[ -f "$AGENCY_DIR/config" ]]; then
  bash -n "$AGENCY_DIR/config" 2>/dev/null
  check "Config file syntax valid" $?
else
  check "Config file exists" 1
fi

# 8. Symlinks present
SYMLINK_OK=true
for cmd in plan-day ship consult; do
  if [[ ! -L "$HOME/.claude/commands/$cmd.md" ]]; then
    SYMLINK_OK=false
    break
  fi
done
$SYMLINK_OK
check "Command symlinks in ~/.claude/commands/" $?

# 9. Project directory accessible (if specified)
if [[ "$PROJECT_PATH" != "." ]]; then
  [ -d "$PROJECT_PATH/.git" ] 2>/dev/null
  check "Git repo at $PROJECT_PATH" $?
fi

echo ""
if [ "$FAILED" -gt 0 ]; then
  echo "FAILED: $FAILED check(s) failed. Run 'agency setup' to fix."
  exit 1
else
  echo "All checks passed."
  exit 0
fi
