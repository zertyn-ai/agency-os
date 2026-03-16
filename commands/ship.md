# /ship — Auto commit, push, and create PR

When the user or orchestrator runs /ship, follow these steps:

## 1. Verify changes exist
```bash
git status --porcelain
```

If no changes, report "Nothing to ship" and stop.

## 2. Determine task info

Look at the current task context. You need:
- `TASK_ID`: e.g. "p1-t1"
- `DESCRIPTION`: short description of what was done
- `ROLE`: which role did this (architect, frontend, qa, docs, analyst)

## 3. Create feature branch
```bash
git checkout -b feat/{TASK_ID}-{short-slug}
```

Use a short slug derived from the description (lowercase, hyphens, max 40 chars).

## 4. Stage and commit
```bash
git add -A
git commit -m "feat({TASK_ID}): {DESCRIPTION}"
```

The pre-commit hook will automatically scan for secrets. If it blocks, fix the issue and retry.

## 5. Push to remote
```bash
git push -u origin feat/{TASK_ID}-{short-slug}
```

## 6. Determine risk level

Analyze the files changed to assign a risk label:

**security-review** — if ANY of these are touched:
- Files with "auth", "middleware", "permission", "session", "token" in path
- Files with "stripe", "payment", "billing", "revenue", "subscription" in path
- Migration files or schema files
- Environment variable files or configs with secrets
- Files containing password hashing, encryption, JWT, OAuth

**dependency-review** — if ANY of these:
- package.json, package-lock.json, pnpm-lock.yaml changed (new deps added)
- Major refactors (>500 lines changed across >10 files)
- Config files (tsconfig, eslint, vite, next.config, etc.)

**low-risk** — if ALL of these:
- Only frontend components, styles, UI changes
- No auth/payment/data logic touched
- No new dependencies
- Less than 500 lines changed

**auto-merge** — if ALL of these:
- Only documentation files (README, CONTEXT.md, CHANGELOG, .md files)
- Only test files (*.test.*, *.spec.*, __tests__/)
- Only style files (*.css, *.scss, tailwind classes only)
- No logic changes whatsoever

Run this to get the files changed:
```bash
git diff --name-only main...HEAD
```

## 7. Create PR with labels
```bash
gh pr create \
  --title "feat({TASK_ID}): {DESCRIPTION}" \
  --body "{PR_BODY}" \
  --label "{RISK_LABEL}"
```

The PR body should include:
```markdown
## Changes
- Brief bullet points of what changed

## Risk Level: {LEVEL}
{Why this risk level was assigned}

## Task
- ID: {TASK_ID}
- Role: {ROLE}
- Complexity: {S/M/L}

## Verification
- [ ] Tests pass
- [ ] Build succeeds
- [ ] Self-review of diff completed
```

If the label doesn't exist in the repo yet, create it:
```bash
gh label create "auto-merge" --color "FFFFFF" --description "Safe to auto-merge" 2>/dev/null || true
gh label create "low-risk" --color "2ECC71" --description "Low risk - Claude review" 2>/dev/null || true
gh label create "dependency-review" --color "F1C40F" --description "New deps or major refactor" 2>/dev/null || true
gh label create "security-review" --color "E74C3C" --description "Auth/payments/data - human review required" 2>/dev/null || true
```

## 8. Return to main
```bash
git checkout main
```

## 9. Update status

If running within Agency OS orchestrator, update the activity log:
```bash
echo "[$(date +%H:%M)] [SHIP] {TASK_ID}: PR created → {PR_URL}" >> $SESSION_DIR/activity.log
```

## IMPORTANT RULES

- NEVER merge the PR. Only create it.
- NEVER push to main. Only push to feature branches.
- If the pre-commit hook blocks the commit, DO NOT bypass it. Fix the secret leak first.
- Always create labels before assigning them.
