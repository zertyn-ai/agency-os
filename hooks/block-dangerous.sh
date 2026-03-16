#!/bin/bash
#
# block-dangerous.sh
# PreToolUse hook — blocks destructive commands before they execute.
# Exit code 2 = block the action and show stderr to Claude.
# Exit code 0 = allow the action.

INPUT=$(cat 2>/dev/null || true)

# Extract command from JSON input
COMMAND=""
if command -v jq &>/dev/null; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || true
fi
if [ -z "$COMMAND" ]; then
  COMMAND=$(echo "$INPUT" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' 2>/dev/null | head -1) || true
fi

# Nothing to check if no command
[ -z "$COMMAND" ] && exit 0

# === DESTRUCTIVE OPERATIONS ===
case "$COMMAND" in
  *"rm -rf /"*|*"rm -rf ~"*|*"rm -rf \$HOME"*)
    echo "BLOCKED: Destructive delete detected" >&2
    exit 2 ;;
  *"chmod -R 777"*)
    echo "BLOCKED: Dangerous permissions change" >&2
    exit 2 ;;
  *"> /dev/"*|*"mkfs"*|*"dd if="*)
    echo "BLOCKED: Destructive system operation" >&2
    exit 2 ;;
  *"shutdown"*|*"reboot"*)
    echo "BLOCKED: System power operation" >&2
    exit 2 ;;
  *"curl"*"| bash"*|*"curl"*"| sh"*|*"wget"*"| bash"*)
    echo "BLOCKED: Piping remote script to shell" >&2
    exit 2 ;;
esac

# === GIT PROTECTION ===
# Detect profile from config
AGENCY_DIR="${AGENCY_DIR:-$HOME/.agency}"
PROFILE="production"
if [ -f "$AGENCY_DIR/profile" ]; then
  PROFILE=$(cat "$AGENCY_DIR/profile" 2>/dev/null || echo "production")
elif [ -f "$AGENCY_DIR/config" ]; then
  PROFILE=$(grep "^AGENCY_PROFILE=" "$AGENCY_DIR/config" 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "production")
fi

# === ORG ISOLATION ===
# If AGENCY_GH_ORG is set and different from AGENCY_GH_USER, block pushes
# to the org from non-production profiles.
if [ -f "$AGENCY_DIR/config" ]; then
  AGENCY_GH_ORG=$(grep "^AGENCY_GH_ORG=" "$AGENCY_DIR/config" 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "")
fi

case "$COMMAND" in
  *"git push --force"*|*"git push -f "*)
    echo "BLOCKED: Force push not allowed" >&2
    exit 2 ;;
  *"git reset --hard"*)
    echo "BLOCKED: Hard reset not allowed" >&2
    exit 2 ;;
  *"git push origin main"*|*"git push origin master"*)
    echo "BLOCKED: Direct push to main/master not allowed. Use /ship to create a PR." >&2
    exit 2 ;;
  *"git push -u origin main"*|*"git push -u origin master"*)
    echo "BLOCKED: Direct push to main/master not allowed. Use /ship to create a PR." >&2
    exit 2 ;;
esac

# === DEPLOY PROTECTION ===
case "$COMMAND" in
  *"vercel deploy"*|*"vercel --prod"*|*"vercel -p "*)
    echo "BLOCKED: Deploy requires manual execution. Merge PR to main instead." >&2
    exit 2 ;;
  *"netlify deploy"*)
    echo "BLOCKED: Deploy requires manual execution. Merge PR to main instead." >&2
    exit 2 ;;
  *"expo publish"*|*"eas submit"*|*"eas build"*)
    echo "BLOCKED: Mobile publish/submit requires manual execution." >&2
    exit 2 ;;
  *"npm publish"*|*"yarn publish"*|*"pnpm publish"*)
    echo "BLOCKED: Package publish requires manual execution." >&2
    exit 2 ;;
esac

# === DATABASE PROTECTION ===
COMMAND_UPPER=$(echo "$COMMAND" | tr '[:lower:]' '[:upper:]' 2>/dev/null) || true
case "${COMMAND_UPPER:-}" in
  *"DROP TABLE"*|*"DROP DATABASE"*|*"DROP COLUMN"*|*"DROP SCHEMA"*)
    echo "BLOCKED: Destructive database operation. Create a migration file instead." >&2
    exit 2 ;;
  *"TRUNCATE "*|*"DELETE FROM"*"WHERE 1"*|*"DELETE FROM"*"WITHOUT"*)
    echo "BLOCKED: Mass data deletion detected." >&2
    exit 2 ;;
esac

# === SENSITIVE FILE PROTECTION ===
case "$COMMAND" in
  *"> .env"*|*">> .env"*|*"> .env."*|*">> .env."*)
    echo "BLOCKED: Direct write to .env files not allowed. Use platform env vars." >&2
    exit 2 ;;
  *"cat ~/.ssh/"*|*"cat /etc/shadow"*|*"cat /etc/passwd"*)
    echo "BLOCKED: Reading sensitive system files not allowed." >&2
    exit 2 ;;
esac

# Allow everything else
exit 0
