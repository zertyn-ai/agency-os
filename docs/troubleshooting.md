# Troubleshooting

Common issues and how to fix them.

---

## Installation

### `setup.sh` says a dependency is missing but I installed it

Make sure the tool is available in your current shell. Try:
```bash
which zellij jq yq gh claude
```

If any command is not found, check:
- Did you install the right version? `yq` must be the [Go version by mikefarah](https://github.com/mikefarah/yq), not the Python one. Check with `yq --version`.
- Did you restart your terminal after installing?
- Is the install location in your `$PATH`?

### Hooks error: "Expected array, but received undefined"

This means `~/.claude/settings.json` has hooks in an incorrect format. Run:
```bash
cd ~/.agency
bash setup.sh
```

Setup will clean old hook entries and add them in the correct format. If the problem persists, you can reset hooks manually:
```bash
# Backup first
cp ~/.claude/settings.json ~/.claude/settings.json.backup

# Remove all Agency OS hooks and re-run setup
agency uninstall
bash ~/.agency/setup.sh
```

### `gh auth` errors during setup

Make sure GitHub CLI is authenticated:
```bash
gh auth status
```

If not authenticated:
```bash
gh auth login
```

Choose HTTPS and follow the prompts.

---

## Daily Workflow

### `/plan-day` command not found

The slash commands are symlinked to `~/.claude/commands/`. Check:
```bash
ls -la ~/.claude/commands/plan-day.md
```

If the symlink is missing or broken, re-run:
```bash
cd ~/.agency && bash setup.sh
```

### Dispatch fails or does nothing

**Check 1:** Is `daily-plan.yaml` present?
```bash
cat ~/.agency/daily-plan.yaml
```

**Check 2:** Is the date in the plan today?
```bash
head -1 ~/.agency/daily-plan.yaml
```
Dispatch only runs plans dated today.

**Check 3:** Is Zellij installed?
```bash
zellij --version
```

**Check 4:** Are you running dispatch inside a Claude Code session?
Dispatch must run in a real terminal, not inside Claude's bash tool. After `/plan-day` approves the plan, it should open a new terminal window automatically.

### Dispatch opens but agents don't start

Check `agency doctor` for issues:
```bash
agency doctor
```

Common causes:
- Claude Code not authenticated (`claude` doesn't work in terminal)
- No git repo at the project path specified in the plan
- Missing `project-codex.yaml` (run `agency init` in the project first)

### Agent is stuck / not making progress

The watcher tab shows status. If an agent appears stuck:
1. Switch to that agent's Zellij tab to see what's happening
2. Check if it's waiting for user input (shouldn't happen with proper permissions, but can)
3. Check the live status: `cat ~/.agency/live/<project>/orchestrator.status`

---

## Windows / WSL

### Slow file operations

If everything feels slow, your projects are probably on the Windows filesystem. Move them:
```bash
# Bad (slow) — mounted Windows drive
/mnt/c/Users/you/projects/

# Good (fast) — native WSL filesystem
~/projects/
```

The Windows mount (`/mnt/c/`) has a 5-10x performance penalty for file operations.

### Zellij rendering issues

Use [Windows Terminal](https://aka.ms/terminal), not cmd.exe or PowerShell directly. Windows Terminal supports the escape codes Zellij needs.

### Claude or gh auth not working

Authentication inside WSL is separate from Windows. You need to authenticate both tools inside WSL:
```bash
gh auth login
claude  # follow the auth flow
```

---

## General

### How do I check if everything is working?

```bash
agency doctor
```

This runs pre-flight checks on all dependencies, configurations, and permissions.

### How do I start over?

```bash
agency uninstall                    # remove hooks, symlinks, PATH
rm -rf ~/.agency                    # remove Agency OS completely
```

Then re-clone and re-install:
```bash
git clone https://github.com/zertyn-ai/agency-os.git ~/.agency
cd ~/.agency
bash setup.sh
```

### How do I update to the latest version?

```bash
agency update
```

This pulls the latest changes, preserves your `config` file, and refreshes all symlinks.

---

## Still stuck?

[Open an issue](https://github.com/zertyn-ai/agency-os/issues) with:
1. Your OS (macOS, Linux, WSL version)
2. Output of `agency doctor`
3. The error message you're seeing
4. What you were trying to do
