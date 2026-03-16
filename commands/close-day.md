# /close-day — End of day session close

First, resolve Agency OS path:
```bash
AGENCY_DIR="$(realpath ~/.claude/commands/close-day.md 2>/dev/null | xargs dirname 2>/dev/null)/.."
[ ! -d "$AGENCY_DIR/scripts" ] && AGENCY_DIR="$HOME/.agency"
```

Run ALL steps in order:

## Step 0: Discover projects worked on today

Read `$AGENCY_DIR/daily-plan.yaml` to get the list of projects and their paths.

```bash
cat "$AGENCY_DIR/daily-plan.yaml"
```

If daily-plan.yaml doesn't exist, read `$AGENCY_DIR/projects.yaml` and look for repos with commits from today.

Run steps 1-5 for EACH project found.

## Step 1: Security scan

```bash
cd {PROJECT_PATH}
gitleaks detect --source . --no-git --no-banner
```
Report results. No automatic fixes.

## Step 2: Quick tech debt scan

- Count TODO/FIXME/HACK comments with grep
- Fix items that take less than 5 minutes
- Log the remaining ones

## Step 3: Update documentation

- Update CONTEXT.md if the architecture changed today
- Update CLAUDE.md if new patterns or rules were established

## Step 4: Generate daily report

Create `$AGENCY_DIR/reports/{YYYY-MM-DD}.md`:

```markdown
# Agency OS Daily Report — {YYYY-MM-DD}

## {PROJECT_NAME}

### Completed
- {description} → PR #{number} (or direct commit)

### Failed / Blocked
- {description} → {reason}

### Tech Debt
- Found: {count} | Fixed: {count} | Remaining: {list}

### PRs Created
| Risk | Count | Status |
|------|-------|--------|
| auto-merge | {n} | merged |
| low-risk | {n} | merged/pending |
| dependency-review | {n} | pending |
| security-review | {n} | pending |

### Security
- Gitleaks: clean / {n} issues found
- New dependencies added: {list or none}
```

To get PRs from today:
```bash
cd {PROJECT_PATH}
gh pr list --state all --search "created:>={YYYY-MM-DD}" --json number,title,labels,state 2>/dev/null
```

## Step 5: Update orchestrator status (if there is an active session)

```bash
SESSION_DIR="$AGENCY_DIR/live/{PROJECT_NAME}"
if [ -d "$SESSION_DIR" ]; then
  echo "completed" > "$SESSION_DIR/orchestrator.status"
  echo "[$(date +%H:%M)] Close-day completed for {PROJECT_NAME}" >> "$SESSION_DIR/activity.log"
fi
```

## Step 6: Final summary

After finishing all projects, show a consolidated summary:
- Total projects closed
- Total tasks completed / failed
- Total PRs created by risk level
- Security alerts if any

## RULES
- Do not merge PRs during close-day
- Do not push to main
- If you find security issues, report but DO NOT fix
- Keep the report factual and concise
- Create the reports directory if it doesn't exist: `mkdir -p "$AGENCY_DIR/reports"`
