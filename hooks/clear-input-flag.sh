#!/bin/bash
#
# clear-input-flag.sh
# PostToolUse hook — clears the needs-input flag after any tool use,
# indicating the user has responded to the approval prompt.

AGENCY_DIR="${AGENCY_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

for project_dir in "$AGENCY_DIR/live"/*/; do
  [[ ! -d "$project_dir" ]] && continue
  name=$(basename "$project_dir")
  if echo "$PWD" | grep -qi "$name"; then
    rm -f "$project_dir/needs-input" "$project_dir/needs-input.detail"
    break
  fi
done

exit 0
