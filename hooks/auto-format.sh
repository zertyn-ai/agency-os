#!/bin/bash
#
# auto-format.sh
# PostToolUse hook — auto-formats files after Claude edits them.
# Receives JSON on stdin with tool_input.file_path

set -euo pipefail

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')

[[ -z "$FILE_PATH" ]] && exit 0
[[ ! -f "$FILE_PATH" ]] && exit 0

# Skip non-code files
case "$FILE_PATH" in
  *.md|*.yaml|*.yml|*.json|*.txt|*.env|*.lock) exit 0 ;;
esac

# Find project root
DIR=$(dirname "$FILE_PATH")
PROJECT_ROOT="$DIR"
while [[ "$PROJECT_ROOT" != "/" ]]; do
  [[ -f "$PROJECT_ROOT/package.json" || -d "$PROJECT_ROOT/.git" ]] && break
  PROJECT_ROOT=$(dirname "$PROJECT_ROOT")
done

cd "$PROJECT_ROOT" 2>/dev/null || exit 0

# Try formatters in order
if [[ -f "node_modules/.bin/prettier" ]]; then
  node_modules/.bin/prettier --write "$FILE_PATH" 2>/dev/null || true
elif [[ -f "node_modules/.bin/biome" ]]; then
  node_modules/.bin/biome format --write "$FILE_PATH" 2>/dev/null || true
elif [[ "$FILE_PATH" == *.py ]] && command -v black &>/dev/null; then
  black --quiet "$FILE_PATH" 2>/dev/null || true
elif [[ "$FILE_PATH" == *.py ]] && command -v ruff &>/dev/null; then
  ruff format "$FILE_PATH" 2>/dev/null || true
fi

exit 0
