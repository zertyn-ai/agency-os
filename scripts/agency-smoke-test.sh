#!/bin/bash
#
# agency-smoke-test.sh — Black-box smoke test for web apps
#
# Builds the app, starts the production server, hits key routes with curl,
# checks for HTTP 200 + content markers + minimum body size.
#
# Usage: bash agency-smoke-test.sh <project-path>
# Output: JSON to stdout
#
# Route config: reads from briefs/<project-name>.smoke if it exists.
# Format: /route|content marker|min_bytes|flags
# Flags: L = follow redirects (curl -L)

set -uo pipefail

PROJECT_PATH="${1:?Usage: agency-smoke-test.sh <project-path>}"
cd "$PROJECT_PATH" 2>/dev/null || { echo '{"smoke_pass":false,"error":"project not found"}'; exit 0; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENCY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_NAME=$(basename "$PROJECT_PATH")

# Load route definitions
SMOKE_FILE="$AGENCY_DIR/briefs/${PROJECT_NAME}.smoke"
ROUTES=()

if [ -f "$SMOKE_FILE" ]; then
  while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
    ROUTES+=("$line")
  done < "$SMOKE_FILE"
fi

if [ ${#ROUTES[@]} -eq 0 ]; then
  echo '{"smoke_pass":false,"error":"no smoke routes configured","routes_tested":0,"routes_passed":0,"failures":["no .smoke file found"]}'
  exit 0
fi

PORT=$((3100 + RANDOM % 100))
BODY_FILE="/tmp/smoke-body-$$"
ROUTES_TESTED=0
ROUTES_PASSED=0
SERVER_PID=""

cleanup() {
  if [ -n "$SERVER_PID" ]; then
    kill -- -"$SERVER_PID" 2>/dev/null || kill "$SERVER_PID" 2>/dev/null
    wait "$SERVER_PID" 2>/dev/null
    lsof -ti :"$PORT" 2>/dev/null | xargs kill 2>/dev/null || true
  fi
  rm -f "$BODY_FILE"
}
trap cleanup EXIT INT TERM

# Build (skip if .next/ is fresh)
NEEDS_BUILD=true
if [ -d ".next" ]; then
  if [ "$(uname)" = "Darwin" ]; then
    NEXT_AGE=$(( $(date +%s) - $(stat -f %m .next 2>/dev/null || echo 0) ))
  else
    NEXT_AGE=$(( $(date +%s) - $(stat -c %Y .next 2>/dev/null || echo 0) ))
  fi
  [ "$NEXT_AGE" -lt 1800 ] && NEEDS_BUILD=false
fi

if $NEEDS_BUILD; then
  BUILD_OUTPUT=$(timeout 180 npx next build 2>&1)
  if [ $? -ne 0 ]; then
    echo "{\"smoke_pass\":false,\"error\":\"build failed\",\"routes_tested\":0,\"routes_passed\":0,\"failures\":[\"next build failed\"]}"
    exit 0
  fi
fi

npx next start -p "$PORT" >/dev/null 2>&1 &
SERVER_PID=$!

READY=false
for i in $(seq 1 30); do
  if curl -sf -o /dev/null "http://localhost:$PORT/" 2>/dev/null; then
    READY=true; break
  fi
  if curl -sf -L -o /dev/null "http://localhost:$PORT/" 2>/dev/null; then
    READY=true; break
  fi
  sleep 0.5
done

if ! $READY; then
  echo "{\"smoke_pass\":false,\"error\":\"server did not start within 15s\",\"routes_tested\":0,\"routes_passed\":0,\"failures\":[\"server timeout\"]}"
  exit 0
fi

FAILURE_LIST=""

for entry in "${ROUTES[@]}"; do
  ROUTE=$(echo "$entry" | cut -d'|' -f1)
  MARKER=$(echo "$entry" | cut -d'|' -f2)
  MIN_SIZE=$(echo "$entry" | cut -d'|' -f3)
  FLAGS=$(echo "$entry" | cut -d'|' -f4)

  ROUTES_TESTED=$((ROUTES_TESTED + 1))

  CURL_FLAGS="-s"
  [[ "$FLAGS" == *"L"* ]] && CURL_FLAGS="$CURL_FLAGS -L"

  HTTP_CODE=$(curl $CURL_FLAGS -o "$BODY_FILE" -w '%{http_code}' "http://localhost:$PORT$ROUTE" 2>/dev/null || echo "000")
  BODY_SIZE=$(wc -c < "$BODY_FILE" 2>/dev/null | tr -d ' ')

  FAIL_REASON=""
  if [ "$HTTP_CODE" != "200" ]; then
    FAIL_REASON="HTTP $HTTP_CODE"
  elif [ "$BODY_SIZE" -lt "$MIN_SIZE" ]; then
    FAIL_REASON="body too small (${BODY_SIZE}b < ${MIN_SIZE}b)"
  elif ! grep -qi "$MARKER" "$BODY_FILE" 2>/dev/null; then
    FAIL_REASON="missing marker: $MARKER"
  fi

  if [ -n "$FAIL_REASON" ]; then
    ESCAPED_ROUTE=$(echo "$ROUTE" | sed 's/"/\\"/g')
    ESCAPED_REASON=$(echo "$FAIL_REASON" | sed 's/"/\\"/g')
    [ -n "$FAILURE_LIST" ] && FAILURE_LIST="$FAILURE_LIST,"
    FAILURE_LIST="$FAILURE_LIST{\"route\":\"$ESCAPED_ROUTE\",\"reason\":\"$ESCAPED_REASON\"}"
  else
    ROUTES_PASSED=$((ROUTES_PASSED + 1))
  fi
done

SMOKE_PASS="true"
[ "$ROUTES_PASSED" -lt "$ROUTES_TESTED" ] && SMOKE_PASS="false"

cat << EOF
{
  "smoke_pass": $SMOKE_PASS,
  "routes_tested": $ROUTES_TESTED,
  "routes_passed": $ROUTES_PASSED,
  "failures": [$FAILURE_LIST],
  "port": $PORT,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
