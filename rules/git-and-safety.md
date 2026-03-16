# Git & Safety Rules

## Branch Policy
- Always work on a feature branch. Never commit to main directly.
- Create PRs via `/ship`. Never push to main.
- Never force push. Never `git reset --hard` on shared branches.
- Commit format: `feat({taskId}): {description}` or `fix({taskId}): {description}`
- New dependencies require justification in the PR description.

## Universal Safety
- Never commit secrets (.env, API keys, tokens, credentials).
- Never run `rm -rf /`, `chmod -R 777`, or destructive system commands.
- Never deploy, publish, or submit without explicit human approval.
- If using worktrees: clean up after work is done (`git worktree prune`).

## Dispatch Enforcement
- When `/plan-day` produces 2+ tasks, dispatch MUST be run to launch parallel agents.
- Single-task plans may be executed in the current session with user confirmation.
- Agents operate on feature branches and create PRs — never merge directly.
