# /ralph-cancel — Cancel Active Ralph Loop

When the user runs `/ralph-cancel`, immediately stop the active Ralph Loop.

## Steps

First resolve the Agency OS path:
```bash
AGENCY_DIR="$(realpath ~/.claude/commands/ralph-cancel.md 2>/dev/null | xargs dirname 2>/dev/null)/.."
[ ! -d "$AGENCY_DIR/live" ] && AGENCY_DIR="$HOME/.agency"
```

1. Check if a loop is active:
```bash
test -f $AGENCY_DIR/live/_ralph/active && echo "active" || echo "inactive"
```

2. If inactive, report: "No active Ralph Loop to cancel." and stop.

3. If active, read the current state:
```bash
cat $AGENCY_DIR/live/_ralph/iteration 2>/dev/null || echo "0"
cat $AGENCY_DIR/live/_ralph/max_iterations 2>/dev/null || echo "?"
cat $AGENCY_DIR/live/_ralph/completion_promise 2>/dev/null || echo "?"
```

4. Deactivate the loop:
```bash
rm -f $AGENCY_DIR/live/_ralph/active
```

5. Print confirmation:
```
Ralph Loop cancelled.
- Completed iterations: {N}
- Max was: {M}
- Promise "{PROMISE}" was not fulfilled.
- State files preserved at $AGENCY_DIR/live/_ralph/ for inspection.
```

## Note
This only removes the `active` flag. State files (prompt, iteration count) are preserved so the user can inspect what happened. To fully clean up:
```bash
rm -rf $AGENCY_DIR/live/_ralph
```
