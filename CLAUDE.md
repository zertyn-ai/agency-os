# Agency OS

Autonomous dev orchestration for Claude Code.

## Structure

```
agency              CLI entrypoint
setup.sh            One-time installer
lib/env.sh          Foundation — all scripts source this
scripts/            Core automation (dispatch, scan, init, watcher, etc.)
hooks/              Claude Code hooks (safety, formatting, metrics)
roles/              17 agent role prompts
commands/           11 slash commands (/plan-day, /ship, /consult, etc.)
rules/              3 auto-loaded rule files
github/             CI workflow templates
```

## How It Works

1. `/plan-day` — plan your day interactively, outputs `daily-plan.yaml`
2. `agency dispatch` — launches parallel Zellij sessions, one per project
3. Each session gets an orchestrator agent that delegates to role-specialized sub-agents
4. Agents work on feature branches and create PRs via `/ship`
5. You review PRs and merge — you're the boss

## Key Commands

| Command | What it does |
|---------|-------------|
| `/plan-day` | Interactive daily planner → generates dispatch plan |
| `/ship` | Auto commit, push, create PR with risk labels |
| `/consult [role]` | Adopt any specialist role on demand |
| `/orchestrate` | Manual orchestration (without dispatch) |
| `/close-day` | End-of-day summary, reports, handoffs |
| `/techdebt` | Scan for technical debt |
| `/ralph` | Autonomous iteration loop |

## Key Roles

17 roles: orchestrator, architect, frontend, backend, mobile, designer, figma-to-web, figma-to-mobile, qa, security, devops, docs, analyst, data, product, writer, reviewer.

## Configuration

Config is stored in `config` (created by `agency setup`). Key variables:
- `AGENCY_PROJECTS_DIR` — colon-separated project directories
- `AGENCY_GH_USER` — GitHub username (auto-detected)
- `AGENCY_GH_ORG` — GitHub org (defaults to user)
- `AGENCY_PERMISSIONS_MODE` — "standard" or "yolo"

## Safety

- `hooks/block-dangerous.sh` blocks destructive git/system operations
- `hooks/auto-approve.sh` auto-approves safe operations, blocks dangerous ones
- `.githooks/pre-commit` scans for leaked secrets
- Agents always work on feature branches, never push to main
- GitHub branch protection is your final safety net
