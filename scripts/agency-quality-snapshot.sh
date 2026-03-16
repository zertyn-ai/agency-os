#!/bin/bash
#
# agency-quality-snapshot.sh — Capture quality metrics as JSON
#
# Runs in any project directory. Detects stack and captures:
#   test_count, test_pass_count, type_error_count, lint_warning_count, commit_hash
#
# Usage: bash agency-quality-snapshot.sh [project-path]
# Output: JSON to stdout.

set -uo pipefail

PROJECT_PATH="${1:-.}"
cd "$PROJECT_PATH" 2>/dev/null || { echo "{}"; exit 0; }

COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
TEST_COUNT=0
TEST_PASS=0
TYPE_ERRORS=0
LINT_WARNINGS=0
STACK="none"

# Detect stack
if [ -f "package.json" ]; then
  STACK="node"
elif [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "setup.cfg" ]; then
  STACK="python"
elif [ -d "scripts" ] && ls scripts/*.sh &>/dev/null 2>&1; then
  STACK="bash"
else
  echo "{\"commit_hash\":\"$COMMIT_HASH\",\"stack\":\"none\"}"
  exit 0
fi

# Node/npm projects
if [ "$STACK" = "node" ]; then
  if grep -q '"test"' package.json 2>/dev/null; then
    TEST_OUTPUT=$(timeout 30 npx --yes jest --bail --maxWorkers=1 --passWithNoTests 2>&1 || true)
    PASS_LINE=$(echo "$TEST_OUTPUT" | grep -E "Tests:.*passed" | tail -1)
    if [ -n "$PASS_LINE" ]; then
      TEST_PASS=$(echo "$PASS_LINE" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' || echo "0")
      TEST_COUNT=$(echo "$PASS_LINE" | grep -oE '[0-9]+ total' | grep -oE '[0-9]+' || echo "0")
    fi
    if [ "$TEST_COUNT" -eq 0 ] && grep -q "vitest" package.json 2>/dev/null; then
      TEST_OUTPUT=$(timeout 30 npx vitest run --reporter=verbose 2>&1 || true)
      TEST_PASS=$(echo "$TEST_OUTPUT" | grep -cE '✓|PASS' || true)
      TEST_COUNT=$TEST_PASS
    fi
  fi

  if [ -f "tsconfig.json" ]; then
    TSC_OUTPUT=$(timeout 30 npx tsc --noEmit 2>&1 || true)
    TYPE_ERRORS=$(echo "$TSC_OUTPUT" | grep -c "error TS" || true)
  fi

  if [ -f ".eslintrc.json" ] || [ -f ".eslintrc.js" ] || [ -f "eslint.config.js" ] || [ -f "eslint.config.mjs" ]; then
    LINT_OUTPUT=$(timeout 30 npx eslint . --format compact 2>&1 || true)
    LINT_WARNINGS=$(echo "$LINT_OUTPUT" | grep -c "Warning\|warning" || true)
  fi
fi

# Python projects
if [ "$STACK" = "python" ]; then
  if command -v pytest &>/dev/null; then
    TEST_COUNT=$(timeout 15 pytest --co -q 2>/dev/null | tail -1 | grep -oE '[0-9]+' | head -1 || echo "0")
    [ -z "$TEST_COUNT" ] && TEST_COUNT=0
    if [ "$TEST_COUNT" -gt 0 ]; then
      PYTEST_OUTPUT=$(timeout 30 pytest --tb=no -q 2>&1 || true)
      PASSED_LINE=$(echo "$PYTEST_OUTPUT" | tail -1)
      TEST_PASS=$(echo "$PASSED_LINE" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' || echo "0")
    fi
  fi

  if command -v mypy &>/dev/null; then
    MYPY_OUTPUT=$(timeout 30 mypy --no-error-summary . 2>&1 || true)
    TYPE_ERRORS=$(echo "$MYPY_OUTPUT" | grep -c ": error:" || true)
  fi

  if command -v ruff &>/dev/null; then
    LINT_WARNINGS=$(timeout 15 ruff check . 2>&1 | grep -c ":" || true)
  elif command -v flake8 &>/dev/null; then
    LINT_WARNINGS=$(timeout 15 flake8 . 2>&1 | grep -c ":" || true)
  fi
fi

# Bash projects
if [ "$STACK" = "bash" ]; then
  for script in scripts/*.sh hooks/*.sh; do
    [ -f "$script" ] || continue
    TEST_COUNT=$((TEST_COUNT + 1))
    bash -n "$script" 2>/dev/null && TEST_PASS=$((TEST_PASS + 1))
  done

  if command -v shellcheck &>/dev/null; then
    SC_OUTPUT=$(shellcheck scripts/*.sh 2>&1 || true)
    TYPE_ERRORS=$(echo "$SC_OUTPUT" | grep -c "^In " || echo "0")
  fi
fi

cat << EOF
{
  "commit_hash": "$COMMIT_HASH",
  "stack": "$STACK",
  "test_count": $TEST_COUNT,
  "test_pass_count": $TEST_PASS,
  "type_error_count": $TYPE_ERRORS,
  "lint_warning_count": $LINT_WARNINGS,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
