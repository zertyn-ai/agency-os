#!/bin/bash
#
# auto-approve.sh
# Hook for Claude Code PermissionRequest events.
# Auto-approves safe operations, blocks dangerous ones.
#
# Three outcomes:
#   approve → operation proceeds without asking
#   deny    → operation blocked
#   ask     → falls back to manual approval (default)

set -euo pipefail

INPUT=$(cat)

TOOL=$(echo "$INPUT" | jq -r '.tool // empty')
COMMAND=$(echo "$INPUT" | jq -r '.input.command // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.input.file_path // empty')

# --- DENY: Always block destructive commands ---
if [[ -n "$COMMAND" ]]; then
  case "$COMMAND" in
    *"rm -rf /"*|*"rm -rf ~"*|*"rm -rf \$HOME"*)
      echo '{"decision": "deny", "reason": "Blocked: destructive delete"}'
      exit 0 ;;
    *"git push --force"*|*"git push -f "*|*"git reset --hard"*)
      echo '{"decision": "deny", "reason": "Blocked: destructive git operation"}'
      exit 0 ;;
    *"chmod -R 777"*)
      echo '{"decision": "deny", "reason": "Blocked: dangerous permissions change"}'
      exit 0 ;;
    *"curl"*"| bash"*|*"curl"*"| sh"*|*"wget"*"| bash"*)
      echo '{"decision": "deny", "reason": "Blocked: piping remote script to shell"}'
      exit 0 ;;
    *"npm publish"*|*"npx publish"*)
      echo '{"decision": "deny", "reason": "Blocked: publish requires manual approval"}'
      exit 0 ;;
    *"> /dev/"*|*"mkfs"*|*"dd if="*)
      echo '{"decision": "deny", "reason": "Blocked: destructive system operation"}'
      exit 0 ;;
    *"shutdown"*|*"reboot"*)
      echo '{"decision": "deny", "reason": "Blocked: system power operation"}'
      exit 0 ;;
  esac
fi

# --- APPROVE: File reads are always safe ---
case "$TOOL" in
  View|ReadFile|ListDirectory|Read|LS)
    echo '{"decision": "approve"}'
    exit 0 ;;
esac

# --- APPROVE: File edits within project scope ---
case "$TOOL" in
  EditFile|WriteFile|CreateFile|file_edit|file_write)
    # Block system files
    if [[ "$FILE_PATH" == /etc/* || "$FILE_PATH" == /usr/* || "$FILE_PATH" == /System/* ]]; then
      echo '{"decision": "deny", "reason": "Blocked: cannot edit system files"}'
      exit 0
    fi
    echo '{"decision": "approve"}'
    exit 0 ;;
esac

# --- APPROVE: Safe bash commands ---
if [[ "$TOOL" == "Bash" || "$TOOL" == "ExecuteCommand" || "$TOOL" == "bash" ]]; then
  SAFE_PREFIXES=(
    "cat " "ls " "find " "grep " "head " "tail " "wc " "echo " "pwd" "which "
    "git status" "git log" "git diff" "git branch" "git checkout" "git add"
    "git commit" "git stash" "git merge" "git rebase" "git fetch" "git pull"
    "npm test" "npm run" "npx " "pnpm " "yarn " "bun " "node " "python " "pip "
    "pytest" "tsc" "eslint" "prettier" "biome"
    "mkdir " "cp " "mv " "touch " "sed " "awk " "sort " "uniq " "jq " "yq "
    "xargs " "diff " "test " "export " "cd " "stat " "file " "du " "df "
  )

  for safe in "${SAFE_PREFIXES[@]}"; do
    if [[ "$COMMAND" == "$safe"* || "$COMMAND" == *"&& $safe"* || "$COMMAND" == *"| $safe"* ]]; then
      echo '{"decision": "approve"}'
      exit 0
    fi
  done
fi

# --- FALLBACK: Ask the user ---
# Flag needs-input so the watcher can alert
AGENCY_DIR="${AGENCY_DIR:-$HOME/.agency}"
for project_dir in "$AGENCY_DIR/live"/*/; do
  [ -d "$project_dir" ] || continue
  name=$(basename "$project_dir")
  if echo "$PWD" | grep -qi "$name"; then
    touch "$project_dir/needs-input"
    echo "Approval needed: $TOOL $(echo "$COMMAND" | head -c 80)" > "$project_dir/needs-input.detail"
    break
  fi
done
echo '{"decision": "ask"}'
