#!/bin/bash
#
# ralph-loop.sh
# Stop hook — autonomous iteration loop engine for Agency OS.
# Blocks Claude from exiting until a completion promise is found in the transcript
# or max iterations are reached. Enforces a minimum of 3 iterations regardless.
#
# Exit code 0 = allow exit (no loop, promise found, or max reached)
# Exit code 2 = block exit and continue iterating

AGENCY_DIR="${AGENCY_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STATE_DIR="$AGENCY_DIR/live/_ralph"
MIN_ITERATIONS=$(cat "$STATE_DIR/min_iterations" 2>/dev/null || echo "3")

# Read stdin
INPUT=$(cat 2>/dev/null || true)

# === No active loop? Allow exit ===
if [ ! -f "$STATE_DIR/active" ]; then
  exit 0
fi

# === Session-specific: only loop for the session that activated ralph ===
ACTIVE_SESSION=$(cat "$STATE_DIR/active" 2>/dev/null || echo "")
CURRENT_SESSION=""
if command -v jq &>/dev/null; then
  CURRENT_SESSION=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null) || true
else
  CURRENT_SESSION=$(echo "$INPUT" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' 2>/dev/null | head -1) || true
fi

# If active file has a session ID and it doesn't match current session, skip
if [ -n "$ACTIVE_SESSION" ] && [ -n "$CURRENT_SESSION" ] && [ "$ACTIVE_SESSION" != "$CURRENT_SESSION" ]; then
  exit 0
fi

# === Read state files ===
ITERATION=$(cat "$STATE_DIR/iteration" 2>/dev/null || echo "0")
MAX_ITERATIONS=$(cat "$STATE_DIR/max_iterations" 2>/dev/null || echo "10")
PROMISE=$(cat "$STATE_DIR/completion_promise" 2>/dev/null || echo "RALPH_COMPLETE")

# === Extract fields from JSON input ===
STOP_HOOK_ACTIVE="false"
TRANSCRIPT_PATH=""

if command -v jq &>/dev/null; then
  STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // "false"' 2>/dev/null) || true
  TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null) || true
else
  if echo "$INPUT" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true' 2>/dev/null; then
    STOP_HOOK_ACTIVE="true"
  fi
  TRANSCRIPT_PATH=$(echo "$INPUT" | sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' 2>/dev/null | head -1) || true
fi

# === Safety: if stop_hook_active and at max, don't recurse ===
if [ "$STOP_HOOK_ACTIVE" = "true" ] && [ "$ITERATION" -ge "$MAX_ITERATIONS" ] 2>/dev/null; then
  rm -f "$STATE_DIR/active"
  echo "[ralph] safety valve: stop_hook_active at max iterations — exiting" >&2
  exit 0
fi

# === MINIMUM ITERATIONS: force at least MIN_ITERATIONS runs, ignore promise ===
if [ "$ITERATION" -lt "$MIN_ITERATIONS" ] 2>/dev/null; then
  NEXT_ITERATION=$((ITERATION + 1))
  echo "$NEXT_ITERATION" > "$STATE_DIR/iteration"
  echo "[ralph] iteration $NEXT_ITERATION/$MAX_ITERATIONS (minimum $MIN_ITERATIONS enforced) — continuing" >&2
  exit 2
fi

# === Check transcript for completion promise (only after minimum reached) ===
PROMISE_FOUND=false
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  if tail -50 "$TRANSCRIPT_PATH" 2>/dev/null | grep -qF "$PROMISE" 2>/dev/null; then
    PROMISE_FOUND=true
  fi
fi

# === Promise found -> clean up and allow exit ===
if [ "$PROMISE_FOUND" = "true" ]; then
  FINAL_ITERATION=$ITERATION
  rm -f "$STATE_DIR/active"
  echo "[ralph] promise \"$PROMISE\" found — completed after $FINAL_ITERATION iteration(s)" >&2
  exit 0
fi

# === Max iterations reached -> clean up and allow exit ===
if [ "$ITERATION" -ge "$MAX_ITERATIONS" ] 2>/dev/null; then
  rm -f "$STATE_DIR/active"
  echo "[ralph] max iterations ($MAX_ITERATIONS) reached — exiting" >&2
  exit 0
fi

# === Continue iterating -> increment and block exit ===
NEXT_ITERATION=$((ITERATION + 1))
echo "$NEXT_ITERATION" > "$STATE_DIR/iteration"
echo "[ralph] iteration $NEXT_ITERATION/$MAX_ITERATIONS — continuing" >&2
exit 2
