# /ralph — Autonomous Iteration Loop

When the user runs `/ralph`, you enter an autonomous iteration loop that keeps working until you fulfill a completion promise.

## Parse Arguments

The user will provide arguments in this format:
```
/ralph "The task prompt here" --min-iterations 3 --max-iterations 10 --completion-promise "DONE"
```

- **First quoted string** = the task prompt (required)
- `--min-iterations N` = minimum forced iterations, hook blocks exit regardless of promise (optional, default: 3)
- `--max-iterations N` = maximum loop iterations (optional, default: 10)
- `--completion-promise "TEXT"` = the string you must output when done (optional, default: "RALPH_COMPLETE")

## Setup the Loop

First resolve the Agency OS path:
```bash
AGENCY_DIR="$(realpath ~/.claude/commands/ralph.md 2>/dev/null | xargs dirname 2>/dev/null)/.."
[ ! -d "$AGENCY_DIR/live" ] && AGENCY_DIR="$HOME/.agency"
```

Run these commands to initialize state:

```bash
mkdir -p "$AGENCY_DIR/live/_ralph"
```

Then write these state files:
1. Write the task prompt to `$AGENCY_DIR/live/_ralph/prompt.md`
2. Write `0` to `$AGENCY_DIR/live/_ralph/iteration`
3. Write the min iterations number to `$AGENCY_DIR/live/_ralph/min_iterations`
4. Write the max iterations number to `$AGENCY_DIR/live/_ralph/max_iterations`
5. Write the completion promise string to `$AGENCY_DIR/live/_ralph/completion_promise`
6. Finally, activate the loop for THIS session only: write the current session ID to the file. Run `echo "$CLAUDE_SESSION_ID" > $AGENCY_DIR/live/_ralph/active` — if $CLAUDE_SESSION_ID is not available, use `claude --version 2>/dev/null | head -1 || echo "unknown"` as fallback. The hook will only loop for this specific session.

## Confirm Setup

Print a summary:
```
Ralph Loop activated:
- Task: {first 80 chars of prompt}...
- Min iterations: {MIN} (forced)
- Max iterations: {MAX}
- Completion promise: "{PROMISE}"
- State: $AGENCY_DIR/live/_ralph/

Starting iteration 1...
```

## Execute the Task

Now execute the task prompt as your first iteration of work. Work on it thoroughly.

## CRITICAL ITERATION RULES

You are in an AUTONOMOUS LOOP. You are expected to use MULTIPLE iterations. One pass is almost NEVER enough.

**After each iteration of work, you MUST do a self-review before even considering completion:**

1. **Re-read the original prompt** from `$AGENCY_DIR/live/_ralph/prompt.md`
2. **Audit your own work** — read back the files you changed. Look for:
   - Missed requirements from the prompt
   - Quality issues, rough edges, incomplete implementations
   - Things that could be better, more polished, more professional
   - Edge cases, error handling, visual polish
3. **Check the iteration count** from `$AGENCY_DIR/live/_ralph/iteration`
   - If you are below the minimum iteration count, the hook will FORCE you to continue regardless. Don't waste those iterations.
   - The user set min/max iterations for a reason — they expect deep, iterative work.
4. **Only output the completion promise when ALL of these are true:**
   - Every requirement in the original prompt is fully addressed
   - You have re-read your changes and found nothing to improve
   - The work is genuinely production-ready, not just "good enough"
   - You are past the minimum iteration count (the hook enforces this anyway)

**DO NOT output the completion promise early.** The hook hard-blocks exit until minimum iterations are reached regardless. The whole point of this loop is iterative refinement. Do a pass, review, improve, review again.

**NEVER use the completion promise word in normal conversation, summaries, or status updates.** Only output it as a standalone signal when truly done. Avoid the word entirely until you're ready to signal completion.

## How the Loop Works

- The loop is powered by a Stop hook — you don't need to do anything special to loop. When you reach the end of your turn, the hook checks for the promise.
- If the promise is NOT found → hook blocks exit (exit 2) → you resume with your file changes intact → keep working.
- If the promise IS found → hook allows exit (exit 0) → session ends.
- If you hit max iterations → session ends regardless.
- To cancel mid-loop, the user can run `/ralph-cancel`.

## Resuming After a Blocked Exit

When the hook blocks your exit and you resume:
1. Read `$AGENCY_DIR/live/_ralph/iteration` to see which iteration you're on
2. Re-read `$AGENCY_DIR/live/_ralph/prompt.md` to refresh on the task
3. Review what you did in previous iterations (read the files you changed)
4. Identify what still needs work and continue
