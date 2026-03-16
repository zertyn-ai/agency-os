#!/bin/bash
#
# agency-init.sh — Initialize a project for Agency OS
#
# Auto-detect stack, scan git history, generate codex, register in projects.yaml.
#
# Usage:
#   agency init                    # run from inside any project
#   agency init ~/projects/myapp   # or pass a path

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/env.sh"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

PROJECT_PATH="${1:-.}"
cd "$PROJECT_PATH" 2>/dev/null || {
  echo "ERROR: Cannot access $PROJECT_PATH"
  exit 1
}

PROJECT_PATH="$(pwd)"
PROJECT_NAME=$(basename "$PROJECT_PATH")

echo ""
echo -e "${CYAN}Agency OS — Project Init: ${BOLD}$PROJECT_NAME${NC}"
echo ""

# ─── 1. Auto-detect stack ───
echo -e "${BLUE}Detecting stack...${NC}"
STACK="unknown"
PKG_MANAGER="none"

if [[ -f "package.json" ]]; then
  if grep -q '"next"' package.json 2>/dev/null; then STACK="nextjs"
  elif grep -q '"expo"' package.json 2>/dev/null; then STACK="expo,react-native"
  elif grep -q '"react"' package.json 2>/dev/null; then STACK="react"
  elif grep -q '"vue"' package.json 2>/dev/null; then STACK="vue"
  elif grep -q '"svelte"' package.json 2>/dev/null; then STACK="svelte"
  else STACK="node"; fi

  [[ -f "pnpm-lock.yaml" ]] && PKG_MANAGER="pnpm"
  [[ -f "bun.lockb" || -f "bun.lock" ]] && PKG_MANAGER="bun"
  [[ -f "yarn.lock" ]] && PKG_MANAGER="yarn"
  [[ -f "package-lock.json" ]] && PKG_MANAGER="npm"
fi

[[ -f "pyproject.toml" || -f "requirements.txt" ]] && STACK="${STACK/unknown/python}"
[[ -f "Cargo.toml" ]] && STACK="${STACK/unknown/rust}"
[[ -f "go.mod" ]] && STACK="${STACK/unknown/go}"
[[ -f "pnpm-workspace.yaml" ]] && STACK="$STACK,monorepo-pnpm"
[[ -f "turbo.json" ]] && STACK="$STACK,turborepo"

echo -e "  Stack: ${GREEN}$STACK${NC}"
echo -e "  Package manager: ${GREEN}$PKG_MANAGER${NC}"

# ─── 2. Scan git history for gotchas ───
echo ""
echo -e "${BLUE}Scanning git history...${NC}"
GOTCHAS=""

if [[ -d ".git" ]]; then
  COMMIT_COUNT=$(git log --oneline 2>/dev/null | wc -l | tr -d ' ')
  echo -e "  Commits: $COMMIT_COUNT"

  # Find bug fix commits (potential gotchas)
  BUG_FIXES=$(git log --oneline -50 2>/dev/null | grep -iE "fix|bug|hotfix|patch|revert" | head -5 || echo "")
  if [[ -n "$BUG_FIXES" ]]; then
    echo -e "  ${YELLOW}Recent fixes (potential gotchas):${NC}"
    while IFS= read -r line; do
      echo -e "    ${DIM}$line${NC}"
      # Extract description for codex
      desc=$(echo "$line" | sed 's/^[a-f0-9]* //')
      GOTCHAS="${GOTCHAS}  - \"$desc\"
"
    done <<< "$BUG_FIXES"
  fi

  # Hot files (most changed in last 50 commits)
  HOT_FILES=$(git log --pretty=format: --name-only -50 2>/dev/null | sort | uniq -c | sort -rn | head -5 | awk '{print $2}' | grep -v '^$' || echo "")
  if [[ -n "$HOT_FILES" ]]; then
    echo -e "  ${YELLOW}Hot files (most changed):${NC}"
    echo "$HOT_FILES" | sed 's/^/    /'
  fi
else
  echo -e "  ${YELLOW}Not a git repo. Initializing...${NC}"
  git init -b main --quiet
  echo "# $PROJECT_NAME" > README.md
  git add README.md
  git commit -m "chore: init $PROJECT_NAME" --quiet 2>/dev/null || true
  echo -e "  ${GREEN}+ Git initialized${NC}"
fi

# ─── 3. Generate project-codex.yaml ───
echo ""
echo -e "${BLUE}Generating codex...${NC}"
bash "$AGENCY_SCRIPTS_DIR/agency-codex-init.sh" "$PROJECT_PATH" 2>/dev/null || {
  echo -e "  ${YELLOW}Codex generation failed. Creating minimal codex.${NC}"
  cat > "project-codex.yaml" << EOF
# project-codex.yaml
principles: []
gotchas:
${GOTCHAS:-  []}
failed_approaches: []
health:
  last_scan: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  stack: "$STACK"
  test_count: 0
  test_pass_rate: 0
  type_errors: 0
EOF
}

# Append detected gotchas if codex was freshly created
if [[ -n "$GOTCHAS" ]] && [[ -f "project-codex.yaml" ]]; then
  if grep -q "gotchas: \[\]" "project-codex.yaml" 2>/dev/null; then
    sed -i.bak "s/gotchas: \[\]/gotchas:/" "project-codex.yaml"
    # Insert gotchas after the gotchas: line
    {
      head -n "$(grep -n "^gotchas:" project-codex.yaml | cut -d: -f1)" project-codex.yaml
      echo "$GOTCHAS"
      tail -n +"$(($(grep -n "^gotchas:" project-codex.yaml | cut -d: -f1) + 1))" project-codex.yaml
    } > project-codex.yaml.tmp && mv project-codex.yaml.tmp project-codex.yaml
    rm -f project-codex.yaml.bak
  fi
fi

echo -e "  ${GREEN}+ project-codex.yaml${NC}"

# ─── 4. Register in projects.yaml ───
echo ""
echo -e "${BLUE}Registering project...${NC}"
REGISTRY="$AGENCY_DIR/projects.yaml"

if [[ ! -f "$REGISTRY" ]]; then
  cat > "$REGISTRY" << 'HEADER'
# Agency OS — Project Registry
projects:
HEADER
fi

# Check if already registered
if grep -q "\"$PROJECT_NAME\"" "$REGISTRY" 2>/dev/null || grep -q "'$PROJECT_NAME'" "$REGISTRY" 2>/dev/null; then
  echo -e "  ${DIM}Already registered${NC}"
else
  HAS_CONTEXT=false
  [[ -f "CONTEXT.md" || -f "CLAUDE.md" || -f "claude.md" ]] && HAS_CONTEXT=true

  cat >> "$REGISTRY" << ENTRY
  - name: "$PROJECT_NAME"
    path: "$PROJECT_PATH"
    stack: "$STACK"
    package_manager: "$PKG_MANAGER"
    has_context: $HAS_CONTEXT
ENTRY
  echo -e "  ${GREEN}+ Registered in projects.yaml${NC}"
fi

# ─── 5. Quality baseline ───
echo ""
echo -e "${BLUE}Running quality baseline...${NC}"
BASELINE_DIR="$AGENCY_DIR/reports"
mkdir -p "$BASELINE_DIR"
BASELINE_FILE="$BASELINE_DIR/${PROJECT_NAME}-baseline.json"

if [[ -x "$AGENCY_SCRIPTS_DIR/agency-quality-snapshot.sh" ]]; then
  bash "$AGENCY_SCRIPTS_DIR/agency-quality-snapshot.sh" "$PROJECT_PATH" > "$BASELINE_FILE" 2>/dev/null || echo "{}" > "$BASELINE_FILE"
  echo -e "  ${GREEN}+ Baseline saved to $BASELINE_FILE${NC}"

  # Show summary
  if command -v jq &>/dev/null; then
    TESTS=$(jq -r '.test_count // 0' "$BASELINE_FILE" 2>/dev/null)
    TYPE_ERR=$(jq -r '.type_error_count // 0' "$BASELINE_FILE" 2>/dev/null)
    echo -e "  Tests: $TESTS | Type errors: $TYPE_ERR"
  fi
else
  echo -e "  ${DIM}Quality snapshot not available${NC}"
fi

# ─── Summary ───
echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}$PROJECT_NAME initialized${NC}"
echo -e "  Stack:     $STACK"
echo -e "  Path:      $PROJECT_PATH"
if [[ -n "$GOTCHAS" ]]; then
  gotcha_count=$(echo "$GOTCHAS" | grep -c "^  -" || echo "0")
  echo -e "  Gotchas:   $gotcha_count detected from git history"
fi
echo ""
echo -e "Ready for ${BOLD}/plan-day${NC}"
echo ""
