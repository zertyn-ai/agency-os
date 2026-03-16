# Agent Behavior Rules

## Context First
- Read CONTEXT.md and project-codex.yaml before any work. Follow existing patterns.
- If project-codex.yaml has `gotchas` or `failed_approaches`, read them to avoid repeating mistakes.

## Context Hygiene
- Keep output minimal. Redirect verbose output to files, not stdout.
- Use `ERROR: [reason]` format for failures. Be specific.
- Context budget: role + CONTEXT.md + task spec = 15-20% of context window. Be economical.
- After completing each task, clean your context — reload only what's needed for the next task.

## Documentation Lookup
- Prefer context7 MCP for documentation queries (`resolve-library-id` -> `get-library-docs`).
- Fall back to WebSearch only if context7 fails or returns no results.
- Never guess API signatures — look them up.

## Commit Discipline
- One task = one atomic commit: `feat({taskId}): {short description}`
- Run tests before reporting done. If no tests exist, write the first ones.
- Never commit generated files, node_modules, or build artifacts.

## Dispatch Enforcement
- When `/plan-day` produces 2+ tasks, run `agency dispatch` to launch parallel agents.
- Agents create feature branches and PRs — humans review and merge.
- Each agent session is tracked in `live/` with status files and activity logs.
