#!/usr/bin/env bash
#
# setup.sh — Agency OS Installer
#
# Idempotent. Every invasive action asks first.
# Usage: bash setup.sh [--configure] [--permissions]

set -euo pipefail

AGENCY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

CONFIGURE_MODE=false
PERMISSIONS_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --configure) CONFIGURE_MODE=true ;;
    --permissions) PERMISSIONS_ONLY=true ;;
  esac
done

# ─── Helpers ───
ask_yn() {
  local prompt="$1" default="${2:-y}"
  if [[ ! -t 0 ]]; then
    [[ "$default" == "y" ]] && return 0 || return 1
  fi
  local yn_hint="[Y/n]"
  [[ "$default" == "n" ]] && yn_hint="[y/N]"
  echo -n "$prompt $yn_hint: "
  read -r answer
  answer="${answer:-$default}"
  [[ "$answer" == "y" || "$answer" == "Y" ]]
}

check_cmd() {
  command -v "$1" &>/dev/null
}

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         Agency OS — Setup                 ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════╝${NC}"
echo ""

# ─── 1. Check Claude Code CLI ───
echo -e "${BLUE}Checking prerequisites...${NC}"
if ! check_cmd claude; then
  echo -e "${RED}Claude Code CLI not found.${NC}"
  echo "Install from: https://docs.anthropic.com/en/docs/claude-code"
  exit 1
fi

CLAUDE_VERSION=$(claude --version 2>/dev/null | head -1 || echo "unknown")
echo -e "  ${GREEN}+${NC} Claude Code: $CLAUDE_VERSION"

# ─── 2. Check OS ───
OS="unknown"
PKG_CMD=""
case "$(uname -s)" in
  Darwin)
    OS="macos"
    if check_cmd brew; then PKG_CMD="brew install"
    else echo -e "  ${YELLOW}Homebrew not found. Install: https://brew.sh${NC}"; fi
    ;;
  Linux)
    OS="linux"
    if check_cmd apt-get; then PKG_CMD="sudo apt-get install -y"
    elif check_cmd dnf; then PKG_CMD="sudo dnf install -y"
    elif check_cmd pacman; then PKG_CMD="sudo pacman -S --noconfirm"
    fi
    ;;
esac
echo -e "  ${GREEN}+${NC} OS: $OS"

# ─── 3. Check dependencies ───
MISSING=()
for dep in jq gh; do
  if ! check_cmd "$dep"; then
    MISSING+=("$dep")
  else
    echo -e "  ${GREEN}+${NC} $dep"
  fi
done

# yq — must be mikefarah/yq Go version
if check_cmd yq; then
  if yq --version 2>&1 | grep -q "mikefarah"; then
    echo -e "  ${GREEN}+${NC} yq (mikefarah/yq)"
  else
    echo -e "  ${RED}x${NC} yq found but it's the wrong version (need mikefarah/yq Go version)"
    echo "    Install: brew install yq  OR  go install github.com/mikefarah/yq/v4@latest"
    MISSING+=("yq")
  fi
else
  MISSING+=("yq")
fi

# Zellij
if check_cmd zellij; then
  echo -e "  ${GREEN}+${NC} zellij"
else
  MISSING+=("zellij")
fi

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo ""
  echo -e "${YELLOW}Missing: ${MISSING[*]}${NC}"
  if [[ -n "$PKG_CMD" ]]; then
    if ask_yn "Install missing dependencies?"; then
      for dep in "${MISSING[@]}"; do
        echo -e "  Installing $dep..."
        case "$dep" in
          zellij)
            if [[ "$OS" == "macos" ]]; then
              brew install zellij 2>/dev/null || {
                echo -e "  ${YELLOW}brew install failed, trying cargo...${NC}"
                cargo install --locked zellij 2>/dev/null || echo -e "  ${RED}Failed to install zellij${NC}"
              }
            else
              # Linux: try cargo or download binary
              if check_cmd cargo; then
                cargo install --locked zellij 2>/dev/null || echo -e "  ${RED}Failed to install zellij${NC}"
              else
                echo -e "  ${YELLOW}Install zellij manually: https://zellij.dev/documentation/installation${NC}"
              fi
            fi
            ;;
          *)
            $PKG_CMD "$dep" 2>/dev/null || echo -e "  ${RED}Failed to install $dep${NC}"
            ;;
        esac
      done
    else
      echo -e "${YELLOW}Skipping dependency installation. Some features may not work.${NC}"
    fi
  else
    echo "Install them manually and re-run setup."
  fi
fi

# ─── 4. Check gh auth ───
echo ""
echo -e "${BLUE}Checking GitHub auth...${NC}"
if check_cmd gh; then
  if gh auth status &>/dev/null; then
    GH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "")
    echo -e "  ${GREEN}+${NC} Authenticated as: $GH_USER"
  else
    echo -e "  ${YELLOW}Not authenticated.${NC}"
    echo "  Run: gh auth login"
    GH_USER=""
  fi
else
  GH_USER=""
fi

# ─── 5. Auto-detect + configure ───
echo ""
echo -e "${BLUE}Configuration...${NC}"

# Try to load existing config
EXISTING_PROJECTS_DIR=""
EXISTING_GH_ORG=""
EXISTING_PERMISSIONS=""
if [[ -f "$AGENCY_DIR/config" ]] && bash -n "$AGENCY_DIR/config" 2>/dev/null; then
  source "$AGENCY_DIR/config" 2>/dev/null || true
  EXISTING_PROJECTS_DIR="${AGENCY_PROJECTS_DIR:-}"
  EXISTING_GH_ORG="${AGENCY_GH_ORG:-}"
  EXISTING_PERMISSIONS="${AGENCY_PERMISSIONS_MODE:-}"
fi

GH_USER="${GH_USER:-$(git config user.name 2>/dev/null || echo "")}"

if [[ "$CONFIGURE_MODE" == true ]] || [[ ! -f "$AGENCY_DIR/config" ]]; then
  # Projects directory
  DEFAULT_PROJECTS="${EXISTING_PROJECTS_DIR:-$HOME/projects}"
  echo ""
  echo -e "  Where are your projects? (colon-separated for multiple dirs)"
  echo -n "  [$DEFAULT_PROJECTS]: "
  if [[ -t 0 ]]; then
    read -r PROJECTS_INPUT
  else
    PROJECTS_INPUT=""
  fi
  PROJECTS_DIR="${PROJECTS_INPUT:-$DEFAULT_PROJECTS}"

  # GitHub org
  DEFAULT_ORG="${EXISTING_GH_ORG:-$GH_USER}"
  echo ""
  echo -n "  GitHub org (default: your user) [$DEFAULT_ORG]: "
  if [[ -t 0 ]]; then
    read -r ORG_INPUT
  else
    ORG_INPUT=""
  fi
  GH_ORG="${ORG_INPUT:-$DEFAULT_ORG}"
else
  PROJECTS_DIR="${EXISTING_PROJECTS_DIR:-$HOME/projects}"
  GH_ORG="${EXISTING_GH_ORG:-$GH_USER}"
fi

# ─── 6. Permissions mode ───
PERMISSIONS_MODE="${EXISTING_PERMISSIONS:-standard}"

if [[ "$PERMISSIONS_ONLY" == true ]] || [[ "$CONFIGURE_MODE" == true ]]; then
  echo ""
  echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────────┐${NC}"
  echo -e "${CYAN}│  Agency OS — Permissions Mode                                      │${NC}"
  echo -e "${CYAN}│                                                                    │${NC}"
  echo -e "${CYAN}│  Agency OS works best with full autonomous permissions.            │${NC}"
  echo -e "${CYAN}│  Agents need unrestricted tool access to: create branches,         │${NC}"
  echo -e "${CYAN}│  run tests, install deps, commit, push, and create PRs.            │${NC}"
  echo -e "${CYAN}│                                                                    │${NC}"
  echo -e "${CYAN}│  1) Standard (default)                                             │${NC}"
  echo -e "${CYAN}│     Uses --permission-mode bypassPermissions                       │${NC}"
  echo -e "${CYAN}│     + Recommended for production and serious projects              │${NC}"
  echo -e "${CYAN}│     + Safety hooks still enforce guardrails                        │${NC}"
  echo -e "${CYAN}│     + GitHub branch protection is your safety net                  │${NC}"
  echo -e "${CYAN}│                                                                    │${NC}"
  echo -e "${CYAN}│  2) YOLO Mode                                                      │${NC}"
  echo -e "${CYAN}│     Uses --dangerously-skip-permissions                            │${NC}"
  echo -e "${CYAN}│     * Maximum speed — zero permission prompts                      │${NC}"
  echo -e "${CYAN}│     * Best for experiments and personal projects                   │${NC}"
  echo -e "${CYAN}│     ! Skips ALL permission checks                                 │${NC}"
  echo -e "${CYAN}│                                                                    │${NC}"
  echo -e "${CYAN}│  Set up GitHub branch protection on production repos:              │${NC}"
  echo -e "${CYAN}│    - Require PR reviews before merging                             │${NC}"
  echo -e "${CYAN}│    - Require status checks to pass                                │${NC}"
  echo -e "${CYAN}│    - Block force pushes to main                                    │${NC}"
  echo -e "${CYAN}└─────────────────────────────────────────────────────────────────────┘${NC}"
  echo ""
  echo -n "  Select [1/2]: "
  if [[ -t 0 ]]; then
    read -r perm_choice
    case "${perm_choice:-1}" in
      2) PERMISSIONS_MODE="yolo" ;;
      *) PERMISSIONS_MODE="standard" ;;
    esac
  fi
fi

echo -e "  Permissions: ${GREEN}$PERMISSIONS_MODE${NC}"

# ─── 7. Write config ───
CONFIG_FILE="$AGENCY_DIR/config"
if [[ -f "$CONFIG_FILE" ]]; then
  if [[ "$CONFIGURE_MODE" == true ]] || [[ "$PERMISSIONS_ONLY" == true ]]; then
    echo ""
    if ask_yn "  Overwrite existing config?"; then
      : # continue
    else
      echo "  Keeping existing config."
      # Still update permissions if --permissions was used
      if [[ "$PERMISSIONS_ONLY" == true ]]; then
        sed -i.bak "s/^AGENCY_PERMISSIONS_MODE=.*/AGENCY_PERMISSIONS_MODE=\"$PERMISSIONS_MODE\"/" "$CONFIG_FILE" 2>/dev/null || true
        rm -f "${CONFIG_FILE}.bak"
        echo "  Updated permissions mode to: $PERMISSIONS_MODE"
      fi
      WRITE_CONFIG=false
    fi
  else
    WRITE_CONFIG=false
  fi
fi

WRITE_CONFIG="${WRITE_CONFIG:-true}"
if [[ "$WRITE_CONFIG" == "true" ]]; then
  cat > "$CONFIG_FILE" << CONF
# Agency OS Configuration
# Generated: $(date '+%Y-%m-%d %H:%M')

AGENCY_PROFILE="production"
AGENCY_GH_USER="$GH_USER"
AGENCY_GH_ORG="$GH_ORG"
AGENCY_PROJECTS_DIR="$PROJECTS_DIR"
AGENCY_PERMISSIONS_MODE="$PERMISSIONS_MODE"
CONF
  echo -e "  ${GREEN}+${NC} Config written to $CONFIG_FILE"
fi

if [[ "$PERMISSIONS_ONLY" == true ]]; then
  echo ""
  echo -e "${GREEN}Permissions updated. Done.${NC}"
  exit 0
fi

# ─── 8. Create directories ───
echo ""
echo -e "${BLUE}Creating directories...${NC}"
for dir in handoffs live metrics feedback history reviews reports; do
  mkdir -p "$AGENCY_DIR/$dir"
done
echo -e "  ${GREEN}+${NC} Runtime directories created"

# ─── 9. Symlink commands ───
echo ""
echo -e "${BLUE}Symlinking commands...${NC}"
mkdir -p "$HOME/.claude/commands"

for cmd_file in "$AGENCY_DIR/commands/"*.md; do
  [[ ! -f "$cmd_file" ]] && continue
  name=$(basename "$cmd_file")
  target="$HOME/.claude/commands/$name"

  if [[ -L "$target" ]]; then
    current=$(readlink "$target" 2>/dev/null || echo "")
    if [[ "$current" == "$cmd_file" ]]; then
      echo -e "  ${DIM}$name (already linked)${NC}"
      continue
    fi
    ln -sf "$cmd_file" "$target"
    echo -e "  ${GREEN}+${NC} $name (updated)"
  elif [[ -f "$target" ]]; then
    cp "$target" "${target}.backup"
    ln -sf "$cmd_file" "$target"
    echo -e "  ${GREEN}+${NC} $name (backed up existing → ${name}.backup)"
  else
    ln -s "$cmd_file" "$target"
    echo -e "  ${GREEN}+${NC} $name"
  fi
done

# ─── 10. Symlink rules ───
echo ""
echo -e "${BLUE}Symlinking rules...${NC}"
mkdir -p "$HOME/.claude/rules"

for rule_file in "$AGENCY_DIR/rules/"*.md; do
  [[ ! -f "$rule_file" ]] && continue
  name=$(basename "$rule_file")
  target="$HOME/.claude/rules/$name"

  if [[ -L "$target" ]]; then
    current=$(readlink "$target" 2>/dev/null || echo "")
    if [[ "$current" == "$rule_file" ]]; then
      echo -e "  ${DIM}$name (already linked)${NC}"
      continue
    fi
    ln -sf "$rule_file" "$target"
    echo -e "  ${GREEN}+${NC} $name (updated)"
  elif [[ -f "$target" ]]; then
    cp "$target" "${target}.backup"
    ln -sf "$rule_file" "$target"
    echo -e "  ${GREEN}+${NC} $name (backed up existing → ${name}.backup)"
  else
    ln -s "$rule_file" "$target"
    echo -e "  ${GREEN}+${NC} $name"
  fi
done

# ─── 11. Merge hooks into settings.json ───
echo ""
echo -e "${BLUE}Installing hooks...${NC}"
SETTINGS_FILE="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"

if [[ ! -f "$SETTINGS_FILE" ]]; then
  echo '{}' > "$SETTINGS_FILE"
fi

# Backup
cp "$SETTINGS_FILE" "${SETTINGS_FILE}.backup" 2>/dev/null || true

# Define hooks to install
# Claude Code hook format: each event has array of {matcher, hooks[]} objects
# SessionStart/SessionEnd are top-level "onSessionStart"/"onSessionEnd" arrays
HOOKS_JSON=$(cat << HOOKSJSON
{
  "hooks": {
    "PreToolUse": [
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "bash $AGENCY_DIR/hooks/block-dangerous.sh"}]}
    ],
    "PostToolUse": [
      {"matcher": "Edit|Write|MultiEdit", "hooks": [{"type": "command", "command": "bash $AGENCY_DIR/hooks/auto-format.sh"}]},
      {"matcher": "*", "hooks": [{"type": "command", "command": "bash $AGENCY_DIR/hooks/clear-input-flag.sh"}]}
    ],
    "PreCompact": [
      {"hooks": [{"type": "command", "command": "bash $AGENCY_DIR/hooks/pre-compact.sh"}]}
    ],
    "Stop": [
      {"hooks": [{"type": "command", "command": "bash $AGENCY_DIR/hooks/ralph-loop.sh"}]}
    ]
  },
  "onSessionStart": [
    {"type": "command", "command": "bash $AGENCY_DIR/scripts/session-start.sh"}
  ],
  "onSessionEnd": [
    {"type": "command", "command": "bash $AGENCY_DIR/scripts/session-end.sh"},
    {"type": "command", "command": "bash $AGENCY_DIR/hooks/session-metrics.sh"}
  ]
}
HOOKSJSON
)

if check_cmd jq; then
  # Merge hooks into settings.json
  # - hooks.*: each event is array of {matcher?, hooks[]} — deduplicate by first hook command
  # - onSessionStart/onSessionEnd: top-level arrays of {type, command} — deduplicate by command
  MERGED=$(jq --argjson new "$HOOKS_JSON" '
    # Merge hooks.* (matcher+hooks format)
    .hooks //= {} |
    reduce ($new.hooks | to_entries[]) as $entry (.;
      .hooks[$entry.key] //= [] |
      # Add entries whose first hook command is not already present
      reduce ($entry.value[]) as $new_entry (.;
        ($new_entry.hooks[0].command) as $cmd |
        if (.hooks[$entry.key] | any(.hooks[0].command == $cmd)) then .
        else .hooks[$entry.key] += [$new_entry]
        end
      )
    ) |
    # Merge onSessionStart (flat {type, command} format)
    if $new.onSessionStart then
      .onSessionStart //= [] |
      reduce ($new.onSessionStart[]) as $entry (.;
        if (.onSessionStart | any(.command == $entry.command)) then .
        else .onSessionStart += [$entry]
        end
      )
    else . end |
    # Merge onSessionEnd (flat {type, command} format)
    if $new.onSessionEnd then
      .onSessionEnd //= [] |
      reduce ($new.onSessionEnd[]) as $entry (.;
        if (.onSessionEnd | any(.command == $entry.command)) then .
        else .onSessionEnd += [$entry]
        end
      )
    else . end
  ' "$SETTINGS_FILE" 2>/dev/null || echo "")

  if [[ -n "$MERGED" ]]; then
    echo "$MERGED" > "$SETTINGS_FILE"
    echo -e "  ${GREEN}+${NC} Hooks installed in settings.json"
  else
    echo -e "  ${RED}Failed to merge hooks. Check $SETTINGS_FILE manually.${NC}"
  fi
else
  echo -e "  ${YELLOW}jq not available — manual hook setup needed.${NC}"
  echo "  Add these hooks to $SETTINGS_FILE"
fi

# ─── 12. PATH ───
echo ""
echo -e "${BLUE}Checking PATH...${NC}"

# Detect shell config
SHELL_RC=""
case "$(basename "${SHELL:-/bin/bash}")" in
  zsh)  SHELL_RC="$HOME/.zshrc" ;;
  bash) SHELL_RC="$HOME/.bashrc" ;;
  *)    SHELL_RC="$HOME/.profile" ;;
esac

if echo "$PATH" | grep -q "$AGENCY_DIR"; then
  echo -e "  ${DIM}Already in PATH${NC}"
elif grep -q "$AGENCY_DIR" "$SHELL_RC" 2>/dev/null; then
  echo -e "  ${DIM}PATH entry exists in $SHELL_RC (reload shell)${NC}"
else
  if ask_yn "  Add agency to PATH (in $SHELL_RC)?"; then
    echo "" >> "$SHELL_RC"
    echo "# Agency OS" >> "$SHELL_RC"
    echo "export PATH=\"$AGENCY_DIR:\$PATH\"" >> "$SHELL_RC"
    echo -e "  ${GREEN}+${NC} Added to $SHELL_RC"
    echo -e "  ${DIM}Run: source $SHELL_RC${NC}"
  fi
fi

# ─── 13. Self-test ───
echo ""
echo -e "${BLUE}Running self-test...${NC}"

# Validate env.sh
if bash -n "$AGENCY_DIR/lib/env.sh" 2>/dev/null; then
  echo -e "  ${GREEN}+${NC} lib/env.sh syntax OK"
else
  echo -e "  ${RED}x${NC} lib/env.sh has syntax errors"
fi

# Validate all scripts
SCRIPT_ERRORS=0
for script in "$AGENCY_DIR"/scripts/*.sh "$AGENCY_DIR"/hooks/*.sh; do
  [[ ! -f "$script" ]] && continue
  if ! bash -n "$script" 2>/dev/null; then
    echo -e "  ${RED}x${NC} $(basename "$script") has syntax errors"
    ((SCRIPT_ERRORS++))
  fi
done
if [[ "$SCRIPT_ERRORS" -eq 0 ]]; then
  echo -e "  ${GREEN}+${NC} All scripts syntax OK"
fi

# Source test
if (source "$AGENCY_DIR/lib/env.sh" 2>/dev/null && [[ -n "$AGENCY_DIR" ]]); then
  echo -e "  ${GREEN}+${NC} env.sh loads correctly"
fi

# ─── 14. Summary ───
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Agency OS — Ready                 ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}What you get:${NC}"
echo -e "    17 specialized agent roles"
echo -e "    11 slash commands (/plan-day, /ship, /consult...)"
echo -e "    Parallel Zellij dispatch"
echo -e "    Production-grade safety hooks"
echo -e "    Quality baselines + regression detection"
echo ""
echo -e "  ${BOLD}Permissions:${NC} $PERMISSIONS_MODE"
echo -e "    Change anytime: agency setup --permissions"
echo ""
echo -e "  ${BOLD}Workflow:${NC}"
echo -e "    1. cd ~/projects/myapp && ${BOLD}agency init${NC}"
echo -e "    2. claude -> ${BOLD}/plan-day${NC}"
echo -e "    3. Review PRs + merge"
echo ""
