<div align="center">

# AGENCY OS

**Turn Claude Code into a dev team.**

Run multiple AI agents in parallel — each with a specialized role, each on its own branch, each opening its own PR. You plan, approve, and merge. They do the rest.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/zertyn-ai/agency-os?style=for-the-badge)](https://github.com/zertyn-ai/agency-os/releases)
[![GitHub stars](https://img.shields.io/github/stars/zertyn-ai/agency-os?style=for-the-badge)](https://github.com/zertyn-ai/agency-os/stargazers)

<!-- Add your demo GIF here — this is the single highest-impact addition to this README
![Agency OS Demo](docs/assets/demo.gif)
-->

[Install](#install) · [Getting Started](#getting-started) · [How It Works](#how-it-works) · [Windows](#windows-via-wsl) · [FAQ](#faq)

</div>

---

## Why?

Claude Code works one session at a time. Your day has 8 tasks across 3 projects. That's 8 sequential sessions — hours of waiting.

Agency OS makes it parallel:

```
9:00 AM  You plan your day with /plan-day         (5 min)
9:05 AM  You approve the plan                      (1 min)
9:06 AM  Dispatch launches 5 agents simultaneously
           ├── frontend agent → builds new dashboard
           ├── backend agent  → adds API endpoints
           ├── mobile agent   → updates screens
           ├── QA agent       → writes integration tests
           └── security agent → audits auth flow
11:00 AM 5 PRs ready for review
```

**You do 3 things:** plan, approve, merge. Everything between is automated.

---

## Install

**Prerequisites:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (authenticated), [GitHub CLI](https://cli.github.com/) (`gh auth login`), macOS or Linux. That's the minimum — `setup.sh` handles the rest.

```bash
git clone https://github.com/zertyn-ai/agency-os.git ~/.agency
cd ~/.agency
bash setup.sh
```

Setup checks your system, installs missing tools (with your approval), and configures everything. Takes about 2 minutes.

<details>
<summary>What does setup.sh actually do?</summary>

| What | Where | Reversible? |
|------|-------|-------------|
| Installs Zellij, jq, yq | System package manager | Standard uninstall |
| Symlinks slash commands | `~/.claude/commands/` | `agency uninstall` |
| Symlinks safety rules | `~/.claude/rules/` | `agency uninstall` |
| Adds hooks to Claude Code | `~/.claude/settings.json` (backup created first) | `agency uninstall` |
| Adds `agency` to PATH | One line in `~/.zshrc` or `~/.bashrc` | `agency uninstall` |

No background processes. No telemetry. No data leaves your machine. `agency uninstall` reverses everything.

</details>

---

## Getting Started

### 1. Register a project

```bash
cd ~/projects/my-app
agency init
```

This scans your project — stack, git history, patterns — and creates a `project-codex.yaml`. Think of it as institutional memory: agents read it before touching your code so they understand existing patterns and known gotchas.

### 2. Plan your day

```bash
claude
> /plan-day
```

Interactive wizard. Claude asks:
- Which projects today?
- What tasks for each?
- What role handles each task? (frontend, backend, security, QA...)
- How complex? (S = 30 min, M = 1-2h, L = 2-4h)

When you confirm, it writes `daily-plan.yaml`.

### 3. Dispatch

After you approve, Agency OS opens a new terminal with [Zellij](https://zellij.dev/) — a terminal multiplexer that runs agents side by side:

```
┌─────────────────────────────────────────────────────┐
│ Tab 1: Watcher     │ Live progress of all agents     │
│ Tab 2: my-saas     │ orchestrator → frontend agent   │
│ Tab 3: api-server  │ orchestrator → backend agent    │
│ Tab 4: mobile-app  │ orchestrator → mobile agent     │
└─────────────────────────────────────────────────────┘
```

Each project gets an **orchestrator** that reads the plan and delegates to specialized sub-agents. Each sub-agent works on a feature branch, runs tests, and opens a PR when done.

### 4. Review and merge

PRs arrive with risk labels so you know what needs careful review:

| Label | Meaning |
|-------|---------|
| `auto-merge` | Safe, small, low-risk changes |
| `low-risk` | Standard feature work |
| `dependency-review` | New dependencies added |
| `security-review` | Touches auth, permissions, or sensitive code |

---

## You Don't Have to Go All-In

Use what fits your workflow. Each layer works independently:

| What you use | What you get |
|-------------|-------------|
| **Just install** | Every Claude Code session gets: destructive command blocking, auto-formatting, session handoffs between conversations |
| **+ slash commands** | `/ship` (auto PR), `/consult security` (instant expert), `/techdebt` (debt scanner), 8 more |
| **+ project init** | Agents learn your codebase patterns and avoid known gotchas |
| **+ dispatch** | Full parallel execution — the complete flow |

Most value comes from just installing. Dispatch is the power move when you're ready.

---

## How It Works

```
/plan-day → daily-plan.yaml → agency dispatch → Zellij session
                                                  │
                                      ┌───────────┼───────────┐
                                      ▼           ▼           ▼
                                 Project A    Project B    Project C
                                      │           │           │
                                 Orchestrator Orchestrator Orchestrator
                                      │           │           │
                                 Sub-agents   Sub-agents   Sub-agents
                                 (roles)      (roles)      (roles)
                                      │           │           │
                                   /ship       /ship       /ship
                                      │           │           │
                                   PR #42      PR #18      PR #7
                                      │           │           │
                                      └───────────┼───────────┘
                                                  ▼
                                          You review + merge
```

**Roles** are detailed prompts that give each agent domain expertise. A frontend agent knows React patterns and accessibility. A security agent knows OWASP and auth flows. The orchestrator picks the right role for each task.

**17 roles available:** orchestrator, architect, frontend, backend, mobile, designer, figma-to-web, figma-to-mobile, qa, security, devops, docs, analyst, data, product, writer, reviewer.

**11 slash commands:** `/plan-day`, `/ship`, `/consult`, `/orchestrate`, `/close-day`, `/context-init`, `/techdebt`, `/permissions`, `/promote`, `/ralph`, `/ralph-cancel`.

<details>
<summary>Full role descriptions</summary>

| Role | Expertise |
|------|-----------|
| `orchestrator` | Task coordination, delegation, QA gate |
| `architect` | System design, project structure, technical decisions |
| `frontend` | Web UI, React, CSS, accessibility |
| `backend` | APIs, databases, server logic |
| `mobile` | React Native, Expo, mobile UX |
| `designer` | Figma, design systems, UX |
| `figma-to-web` | Figma design → pixel-perfect web implementation |
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

Use any role on demand without dispatch: `/consult security` → ask your question.

</details>

<details>
<summary>Full command descriptions</summary>

| Command | What it does |
|---------|-------------|
| `/plan-day` | Interactive daily planner → generates dispatch plan |
| `/ship` | Auto commit, push, create PR with risk labels |
| `/consult [role]` | Adopt any specialist role on demand |
| `/orchestrate` | Manual orchestration without dispatch |
| `/close-day` | End-of-day summary and handoffs |
| `/context-init` | Generate CONTEXT.md for a project |
| `/techdebt` | Scan codebase for technical debt |
| `/permissions` | Review and adjust file permissions |
| `/promote` | Pre-promotion checklist for production readiness |
| `/ralph` | Autonomous iteration loop |
| `/ralph-cancel` | Cancel active ralph loop |

</details>

---

## Safety

Agents are powerful. Agency OS adds guardrails:

| Layer | What it does |
|-------|-------------|
| **Hooks** | Block `force push`, `rm -rf`, `git reset --hard`, `DROP TABLE` before they execute |
| **Auto-format** | Runs your formatter (prettier/biome/black) after every file edit |
| **Feature branches** | Agents never touch `main` — always a new branch |
| **Risk labels** | PRs tagged by risk level so you know what to scrutinize |
| **Quality baselines** | Snapshots before/after — detects regressions in tests, types, lint |
| **Pre-commit scan** | Catches leaked API keys and secrets before they're committed |
| **Branch protection** | Your GitHub settings are the final gate — agents can't bypass them |

---

## Windows (via WSL)

Agency OS runs on Windows through [WSL](https://learn.microsoft.com/en-us/windows/wsl/install) (Windows Subsystem for Linux).

```powershell
# PowerShell (run as Administrator)
wsl --install
```

Restart your PC. Open **Ubuntu** from the Start Menu:

```bash
git clone https://github.com/zertyn-ai/agency-os.git ~/.agency
cd ~/.agency
bash setup.sh
```

**Three things to know:**
1. **Keep projects inside WSL** (`~/projects/`), not on the Windows mount (`/mnt/c/...`) — 5-10x speed difference.
2. **Use [Windows Terminal](https://aka.ms/terminal)** for proper Zellij rendering.
3. **Auth is separate** — `gh auth login` and `claude` auth must be done inside WSL.

---

## FAQ

**How much does this cost?**
Agency OS is free and open-source (MIT). But Claude Code uses the Anthropic API — each agent session consumes tokens. Running 5 parallel agents ≈ 5x the token usage of a single session. Check [Claude Code pricing](https://docs.anthropic.com/en/docs/claude-code) for current rates.

**Can a team use this?**
Yes. Each developer installs Agency OS on their machine, registers their projects, and runs their own daily plans. There's no shared server — everything is local.

**What if an agent fails mid-task?**
The watcher tab shows real-time status. Failed agents are marked clearly. Other agents continue working. You can re-run failed tasks by creating a new plan with just those tasks.

**What if I don't like what an agent did?**
Every agent works on a feature branch. If a PR isn't good, close it and delete the branch. Your main branch is never touched.

**Do I need Zellij?**
For parallel dispatch, yes — Zellij runs the agents side by side. But everything else (slash commands, safety hooks, `/consult`, `/ship`) works without Zellij in any normal Claude Code session.

**What languages/frameworks does it support?**
Any. Agency OS doesn't care about your stack — it's a layer on top of Claude Code. If Claude Code can work with your project, Agency OS can dispatch agents for it.

**Something isn't working — where do I get help?**
See [Troubleshooting](docs/troubleshooting.md) for common issues, or [open an issue](https://github.com/zertyn-ai/agency-os/issues).

---

## Configuration

The `config` file (created by `setup.sh`) controls behavior:

```bash
AGENCY_PROFILE="production"
AGENCY_GH_USER="your-github-username"
AGENCY_GH_ORG="your-org"
AGENCY_PROJECTS_DIR="$HOME/projects:$HOME/work"  # colon-separated
AGENCY_PERMISSIONS_MODE="standard"                # or "yolo"
```

**Permissions modes:**
- **standard** (default) — Agents run with `bypassPermissions`. Safety hooks still enforce guardrails. Recommended.
- **yolo** — `dangerously-skip-permissions`. Zero prompts, maximum speed. For experiments and personal projects.

Change anytime: `agency setup --permissions`

---

## CLI Reference

```
agency setup      Install — check deps, symlinks, hooks, PATH
agency init       Register project — scan stack, generate codex
agency dispatch   Launch parallel agents from daily plan
agency scan       Discover and update project registry
agency status     Show running agent sessions
agency doctor     Pre-flight health checks
agency update     Pull latest + refresh symlinks
agency uninstall  Remove all symlinks, hooks, PATH entry (clean)
```

---

## Updating

```bash
agency update
```

Pulls latest, handles local changes, refreshes symlinks.

## Uninstalling

```bash
agency uninstall
```

Removes symlinks, hooks, and PATH entry. Does not delete `~/.agency` — remove it yourself if you want a full cleanup.

## License

MIT
