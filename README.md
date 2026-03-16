# Agency OS

> Turn Claude Code into a full dev agency.
> 17 roles. 11 commands. Parallel Zellij dispatch. Production-grade safety.

## The Problem

Claude Code is powerful, but it works one session at a time. You describe a task, it executes, you review. For a single fix, that's fine. For a real workday — 6 tasks across 3 projects — you're bottlenecked on sequential execution.

Agency OS turns Claude Code into a **parallel autonomous dev team**. You plan your day, approve the plan, and dispatch launches specialized agents in parallel Zellij sessions. Each agent gets a role (frontend, backend, security, QA...), works on a feature branch, and creates a PR when done. You review and merge.

**Three human touchpoints:** approve plan, review PRs, merge.

## How It Works

```
You → /plan-day → Approve → agency dispatch → Zellij
                                                 ├── [Watcher] Live progress dashboard
                                                 ├── [saas-app] Orchestrator → frontend agent → /ship → PR #42
                                                 ├── [mobile]   Orchestrator → mobile agent   → /ship → PR #18
                                                 └── [api]      Orchestrator → backend agent  → /ship → PR #7
                                                                                  ↓
                                                                          You review + merge
```

### The Dispatch Flow

1. **`/plan-day`** — Interactive planning. You describe what you want done. Claude asks clarifying questions until every task is executable.
2. **Plan YAML** — Tasks are written to `daily-plan.yaml` with roles, specs, dependencies, and complexity estimates.
3. **`agency dispatch`** — Reads the plan, creates a Zellij session with one tab per project.
4. **Orchestrator** — Each project gets an orchestrator agent that reads the plan and delegates tasks to role-specialized sub-agents.
5. **Sub-agents** — Each task is handled by a specialist (frontend, backend, security, QA...) with full role context injected.
6. **`/ship`** — When a task is done, the agent creates a feature branch, commits, pushes, and opens a PR with risk labels.
7. **Watcher** — The first Zellij tab shows real-time progress: which agents are working, what they're doing, and when they finish.
8. **You review** — PRs arrive with risk labels (auto-merge, low-risk, dependency-review, security-review). You review and merge.

### The Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Rules (3 files)        Always loaded into every session     │
│ ├── agent-behavior.md  Context-first, atomic commits        │
│ ├── code-quality.md    Tests, types, lint                   │
│ └── git-and-safety.md  Branch policy, safety                │
├─────────────────────────────────────────────────────────────┤
│ Roles (17 files)       Specialist prompts                   │
│ ├── orchestrator.md    Coordinates task execution           │
│ ├── frontend.md        Web UI, React, accessibility         │
│ ├── backend.md         APIs, databases, server logic        │
│ ├── security.md        OWASP, auth, vulnerability analysis  │
│ └── ... 13 more                                             │
├─────────────────────────────────────────────────────────────┤
│ Commands (11 files)    Slash commands for Claude Code        │
│ ├── /plan-day          Interactive daily planner             │
│ ├── /ship              Auto PR with risk labels              │
│ ├── /consult           On-demand expert role                 │
│ └── ... 8 more                                              │
├─────────────────────────────────────────────────────────────┤
│ Hooks (7 files)        Safety + automation                  │
│ ├── block-dangerous    Blocks destructive commands           │
│ ├── auto-format        Auto-formats after edits              │
│ ├── session-metrics    Captures performance data             │
│ └── ... 4 more                                              │
├─────────────────────────────────────────────────────────────┤
│ Scripts                Core automation                       │
│ ├── dispatch           Parallel Zellij launcher              │
│ ├── watcher            Live progress dashboard               │
│ ├── scan               Project discovery                     │
│ └── init               Project analysis + codex              │
├─────────────────────────────────────────────────────────────┤
│ Zellij                 Terminal multiplexer                  │
│ └── Parallel sessions with tab-per-project layout            │
└─────────────────────────────────────────────────────────────┘
```

Each layer is independent. Use just the rules and commands for everyday Claude Code enhancement. Add dispatch when you're ready for parallel execution.

## Quick Start

```bash
git clone https://github.com/zertyn-ai/agency-os.git ~/.agency
cd ~/.agency
bash setup.sh
```

Then for each project:
```bash
cd ~/projects/myapp
agency init
```

Start your day:
```bash
claude
> /plan-day
```

## What You Get

### 17 Specialized Roles

| Role | Expertise |
|------|-----------|
| `orchestrator` | Task coordination, delegation, QA gate |
| `architect` | System design, project structure, technical decisions |
| `frontend` | Web UI, React, CSS, accessibility |
| `backend` | APIs, databases, server logic |
| `mobile` | React Native, Expo, mobile UX |
| `designer` | Figma, design systems, UX |
| `figma-to-web` | Figma design → web implementation |
| `figma-to-mobile` | Figma design → mobile implementation |
| `qa` | Testing, edge cases, quality assurance |
| `security` | OWASP, auth, vulnerability analysis |
| `devops` | CI/CD, infrastructure, deployment |
| `docs` | Documentation, READMEs, guides |
| `analyst` | Data analysis, metrics, reporting |
| `data` | Data engineering, pipelines, schemas |
| `product` | Product strategy, specs, prioritization |
| `writer` | Technical writing, copy, content |
| `reviewer` | Code review, PR analysis |

### 11 Workflow Commands

| Command | What it does |
|---------|-------------|
| `/plan-day` | Interactive daily planner → generates dispatch plan |
| `/ship` | Auto commit, push, create PR with risk labels |
| `/consult [role]` | Adopt any specialist role on demand |
| `/orchestrate` | Manual orchestration without dispatch |
| `/close-day` | End-of-day summary, reports, handoffs |
| `/context-init` | Generate CONTEXT.md for a project |
| `/techdebt` | Scan codebase for technical debt |
| `/permissions` | Review and adjust file permissions |
| `/promote` | Promote changes between environments |
| `/ralph` | Autonomous iteration loop |
| `/ralph-cancel` | Cancel active ralph loop |

### Always-On Enhancement

Even without dispatch, Agency OS enhances every Claude Code session:

- **Safety hooks** block destructive commands (force push, rm -rf, DROP TABLE)
- **Auto-format** runs prettier/biome/black after every file edit
- **Session continuity** — handoff files carry context between sessions
- **Project codex** — machine-maintained institutional memory per project
- **Quality baselines** — detect regressions before they ship

### `/consult` — On-Demand Expert Roles

Use any specialist role in your current session without running dispatch:

```
claude
> /consult security
> Review this auth middleware for vulnerabilities
```

### Production-Grade Safety

| Mechanism | What it does |
|-----------|-------------|
| `block-dangerous.sh` | Blocks force push, hard reset, rm -rf, DROP TABLE |
| `auto-approve.sh` | Auto-approves safe ops, blocks dangerous ones |
| `.githooks/pre-commit` | Scans for leaked API keys and secrets |
| Feature branches | Agents never push to main |
| Risk labels | PRs labeled: auto-merge, low-risk, dependency-review, security-review |
| Quality baselines | Regression detection before merge |
| GitHub branch protection | Your final safety net |

## CLI Reference

```bash
agency setup      # One-time install — deps, symlinks, hooks, PATH
agency init       # Analyze project — generate codex, register, baseline
agency dispatch   # Launch parallel agent sessions from daily plan
agency scan       # Scan all projects for status and signals
agency status     # Show running agent sessions
agency doctor     # Run pre-flight health checks
agency update     # Pull latest changes and refresh symlinks
agency uninstall  # Remove symlinks, hooks, PATH entry
```

## Concepts

### Autonomous Dev Orchestration

Agency OS implements a pattern where AI agents operate autonomously within well-defined guardrails. The orchestrator reads a plan, delegates tasks to role-specialized sub-agents, validates their output, and creates PRs. The human approves the plan upfront and reviews PRs at the end.

### Role-Based Agent Specialization

Each role file is a detailed prompt that gives an agent domain expertise. A frontend agent knows about React patterns, accessibility, and CSS. A security agent knows OWASP, auth flows, and common vulnerabilities. The orchestrator reads the appropriate role file and injects it into each sub-agent's system prompt.

### Project Codex — Institutional Memory

`project-codex.yaml` is a per-project file that tracks gotchas, failed approaches, and health metrics. Agents read it before starting work to avoid repeating mistakes. It's updated automatically after each session with new learnings from errors.

### Quality Gates — Trust But Verify

Quality snapshots capture test counts, type errors, and lint warnings before and after agent work. If quality regresses, the system detects it. Smoke tests can verify that web apps still serve expected content after changes.

## Configuration

The `config` file (created by `agency setup`) controls behavior:

```bash
AGENCY_PROFILE="production"
AGENCY_GH_USER="your-github-username"
AGENCY_GH_ORG="your-org"
AGENCY_PROJECTS_DIR="$HOME/projects:$HOME/work"  # colon-separated
AGENCY_PERMISSIONS_MODE="standard"  # or "yolo"
```

### Permissions Modes

- **standard** — Uses `--permission-mode bypassPermissions`. Safety hooks still run. Recommended.
- **yolo** — Uses `--dangerously-skip-permissions`. Maximum speed, zero prompts. For experiments.

Change anytime: `agency setup --permissions`

## Updating

```bash
agency update
```

Pulls latest changes, handles local modifications gracefully, and refreshes all symlinks.

## Uninstalling

```bash
agency uninstall
```

Removes symlinks from `~/.claude/commands/` and `~/.claude/rules/`, removes hooks from `settings.json`, and removes the PATH entry. Does **not** delete the directory — you do that yourself if you want.

## License

MIT
