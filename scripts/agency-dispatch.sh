#!/bin/bash
#
# agency-dispatch.sh — Launch parallel agent sessions from daily plan.
#
# Reads daily-plan.yaml, prepares live session directories, and launches
# Zellij with a watcher pane + one tab per project.
#
# Usage: agency dispatch [plan-file]

set -euo pipefail

# Source env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/env.sh"

PLAN_FILE="${1:-$AGENCY_DIR/daily-plan.yaml}"
LIVE_DIR="$AGENCY_LIVE_DIR"
DATE=$(date +%Y-%m-%d)
FIRST_PROJECT=$(yq ".projects[0].name" "$PLAN_FILE" 2>/dev/null || echo "default")
SESSION_NAME="agency-${DATE}-${FIRST_PROJECT}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Preflight ───
check_deps() {
  local missing=()
  command -v yq &>/dev/null || missing+=("yq")
  command -v claude &>/dev/null || missing+=("claude")
  command -v zellij &>/dev/null || missing+=("zellij")
  command -v gh &>/dev/null || missing+=("gh")

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo -e "${RED}Missing: ${missing[*]}${NC}"
    echo "Run: agency setup"
    exit 1
  fi

  # Validate yq version
  if ! yq --version 2>&1 | grep -q "mikefarah"; then
    echo -e "${RED}Wrong yq version. Agency OS requires mikefarah/yq (Go version).${NC}"
    echo "Install: brew install yq  OR  go install github.com/mikefarah/yq/v4@latest"
    exit 1
  fi
}

check_plan() {
  if [[ ! -f "$PLAN_FILE" ]]; then
    echo -e "${RED}No plan found: $PLAN_FILE${NC}"
    echo "Run: claude -> /plan-day"
    exit 1
  fi

  # Check plan date
  local plan_date
  plan_date=$(yq '.date' "$PLAN_FILE" 2>/dev/null || echo "")
  if [[ "$plan_date" != "$DATE" ]]; then
    echo -e "${YELLOW}Plan date ($plan_date) doesn't match today ($DATE).${NC}"
    echo -n "Continue anyway? [y/N]: "
    if [[ -t 0 ]]; then
      read -r answer
      [[ "$answer" != "y" && "$answer" != "Y" ]] && exit 0
    else
      echo "Non-interactive — skipping stale plan."
      exit 0
    fi
  fi
}

# ─── Detect active agency Zellij sessions ───
detect_active_sessions() {
  ACTIVE_AGENCY_SESSIONS=()
  ACTIVE_SESSION_COUNT=0
  local sessions
  sessions=$(zellij list-sessions 2>/dev/null | sed $'s/\033\[[0-9;]*m//g' || echo "")
  [[ -z "$sessions" ]] && return

  while IFS= read -r line; do
    [[ "$line" == *"EXITED"* ]] && continue
    local session_name
    session_name=$(echo "$line" | awk '{print $1}')
    if [[ "$session_name" == agency-* ]]; then
      ACTIVE_AGENCY_SESSIONS+=("$session_name")
    fi
  done <<< "$sessions"
  ACTIVE_SESSION_COUNT=${#ACTIVE_AGENCY_SESSIONS[@]}
}

# ─── Detect new projects not yet in live dir ───
detect_new_projects() {
  NEW_PROJECT_INDICES=()
  NEW_PROJECT_COUNT=0
  local project_count
  project_count=$(yq '.projects | length' "$PLAN_FILE")

  for i in $(seq 0 $((project_count - 1))); do
    local name
    name=$(yq ".projects[$i].name" "$PLAN_FILE")
    if [[ ! -d "$LIVE_DIR/$name" ]]; then
      NEW_PROJECT_INDICES+=("$i")
    fi
  done
  NEW_PROJECT_COUNT=${#NEW_PROJECT_INDICES[@]}
}

# ─── Prepare live session directories ───
prepare_sessions() {
  local append_mode=false
  [[ "${1:-}" == "--append" ]] && append_mode=true

  if [[ "$append_mode" == false ]]; then
    rm -rf "$LIVE_DIR"
  fi

  local project_count
  project_count=$(yq '.projects | length' "$PLAN_FILE")

  for i in $(seq 0 $((project_count - 1))); do
    local name
    name=$(yq ".projects[$i].name" "$PLAN_FILE")
    local session_dir="$LIVE_DIR/$name"

    if [[ "$append_mode" == true && -d "$session_dir" ]]; then
      continue
    fi

    mkdir -p "$session_dir/tasks"

    echo "waiting" > "$session_dir/orchestrator.status"
    echo "[$(date +%H:%M)] Session prepared for $name" > "$session_dir/activity.log"
    date +%s > "$session_dir/session.started_at"
    touch "$session_dir/events.jsonl"
    touch "$session_dir/git-activity.log"
    touch "$session_dir/error.log"

    local task_count
    task_count=$(yq ".projects[$i].tasks | length" "$PLAN_FILE")

    for j in $(seq 0 $((task_count - 1))); do
      local task_id
      task_id=$(yq ".projects[$i].tasks[$j].id" "$PLAN_FILE")
      echo "pending" > "$session_dir/tasks/$task_id.status"
    done

    echo -e "  ${GREEN}+ $name ($task_count tasks)${NC}"
  done
}

# ─── Create launcher script per project ───
create_launcher() {
  local index=$1
  local name path tasks_yaml session_dir

  name=$(yq ".projects[$index].name" "$PLAN_FILE")
  path=$(yq ".projects[$index].path" "$PLAN_FILE")
  path="${path/#\~/$HOME}"
  session_dir="$LIVE_DIR/$name"

  tasks_yaml=$(yq -o=yaml ".projects[$index].tasks" "$PLAN_FILE")
  local timestamp
  timestamp=$(date +%H:%M)

  # Build prompt file
  local prompt_file="/tmp/agency-prompt-$name.md"
  cat "$AGENCY_ROLES_DIR/orchestrator.md" > "$prompt_file"

  # Pre-session context injection
  local context_block=""
  if [[ -d "$path/.git" ]]; then
    local recent_commits
    recent_commits=$(git -C "$path" log --oneline -10 2>/dev/null || echo "(no commits)")
    context_block+="## Recent Changes (last 10 commits)
$recent_commits

"
  fi

  # Open PRs (non-blocking)
  local open_prs
  open_prs=$(cd "$path" && gh pr list --state open --limit 5 2>/dev/null || echo "")
  if [[ -n "$open_prs" ]]; then
    context_block+="## Open PRs
$open_prs

"
  fi

  # Handoff from previous session
  if [[ -f "$AGENCY_HANDOFFS_DIR/$name.md" ]]; then
    local handoff
    handoff=$(cat "$AGENCY_HANDOFFS_DIR/$name.md")
    context_block+="## Previous Session Handoff
$handoff

"
  fi

  # Resolve absolute roles path for the orchestrator
  local roles_abs_path
  roles_abs_path="$(realpath "$AGENCY_ROLES_DIR" 2>/dev/null || echo "$AGENCY_ROLES_DIR")"

  cat >> "$prompt_file" << EOF

---

## Pre-Session Context
$context_block
## Session Info
- PROJECT: $name
- SESSION_DIR: $session_dir
- ROLES_DIR: $roles_abs_path
- DATE: $DATE
- AGENCY_DIR: $AGENCY_DIR

Before starting, run these commands to initialize tracking:

mkdir -p $session_dir/tasks
echo "running" > $session_dir/orchestrator.status
echo "[$timestamp] Orchestrator started for $name" >> $session_dir/activity.log

## Assigned tasks:

$tasks_yaml

---

Read this project's CONTEXT.md. Execute the tasks in order, respecting dependencies.
Use the Task tool to delegate to sub-agents. For each sub-agent, read the role prompt from $roles_abs_path/{role}.md.
Keep the status files in $session_dir up to date (see instructions in your role prompt).

IMPORTANT: Upon completing each task, run the /ship command to automatically create a PR.
EOF

  # Build launcher script
  local launcher="/tmp/agency-launch-$name.sh"

  # Determine claude flags based on permissions mode
  local claude_flags="--permission-mode bypassPermissions --worktree"
  if [[ "$AGENCY_PERMISSIONS_MODE" == "yolo" ]]; then
    claude_flags="--dangerously-skip-permissions --worktree"
  fi

  cat > "$launcher" << LAUNCHER
#!/bin/bash
cd "$path"

echo ""
echo "======================================"
echo "  Orchestrator: $name"
echo "  Path: $path"
echo "  Session: $session_dir"
echo "  Permissions: $AGENCY_PERMISSIONS_MODE"
echo "======================================"
echo ""

claude $claude_flags --system-prompt "\$(cat "$prompt_file")" -- "Start the session. Read CONTEXT.md and execute the assigned tasks."
LAUNCHER

  chmod +x "$launcher"
  echo "$launcher"
}

# ─── Generate Zellij session layout ───
generate_session_layout() {
  local project_count=$1
  local layout_file="/tmp/agency-layout-${DATE}-${FIRST_PROJECT}.kdl"

  cat > "$layout_file" << 'KDL_START'
layout {
    default_tab_template {
        children
        pane size=1 borderless=true {
            plugin location="compact-bar"
        }
    }
KDL_START

  # Tab 1: Watcher
  cat >> "$layout_file" << KDL_WATCHER
    tab name="Watcher" focus=true {
        pane command="bash" {
            args "-c" "$AGENCY_SCRIPTS_DIR/agency-watcher.sh"
        }
    }
KDL_WATCHER

  # Tab per project
  for i in $(seq 0 $((project_count - 1))); do
    local name launcher
    name=$(yq ".projects[$i].name" "$PLAN_FILE")
    launcher=$(create_launcher "$i")

    cat >> "$layout_file" << KDL_PROJECT
    tab name="$name" {
        pane split_direction="vertical" {
            pane size="80%" command="bash" {
                args "-c" "$launcher; exec bash"
            }
            pane size="20%" command="bash" {
                args "-c" "sleep 2 && tail -f $LIVE_DIR/$name/activity.log 2>/dev/null || echo 'Waiting for activity...'; exec bash"
            }
        }
    }
KDL_PROJECT
  done

  echo "}" >> "$layout_file"
  echo "$layout_file"
}

# ─── Generate per-tab layout (for injection) ───
generate_tab_layout() {
  local index=$1
  local name launcher
  name=$(yq ".projects[$index].name" "$PLAN_FILE")
  launcher=$(create_launcher "$index")

  local tab_layout="/tmp/agency-tab-$name.kdl"

  cat > "$tab_layout" << KDL_TAB
layout {
    pane split_direction="vertical" {
        pane size="80%" command="bash" {
            args "-c" "$launcher; exec bash"
        }
        pane size="20%" command="bash" {
            args "-c" "sleep 2 && tail -f $LIVE_DIR/$name/activity.log 2>/dev/null || echo 'Waiting...'; exec bash"
        }
    }
}
KDL_TAB

  echo "$tab_layout"
}

# ─── Inject into running session ───
inject_into_session() {
  local target_session=$1

  echo -e "${BLUE}Preparing new sessions (append mode)...${NC}"
  prepare_sessions --append
  echo ""

  echo -e "${GREEN}Injecting $NEW_PROJECT_COUNT new tab(s) into '$target_session'...${NC}"

  for i in "${NEW_PROJECT_INDICES[@]}"; do
    local name tab_layout
    name=$(yq ".projects[$i].name" "$PLAN_FILE")
    tab_layout=$(generate_tab_layout "$i")

    if [[ -n "${ZELLIJ:-}" ]]; then
      zellij action new-tab --layout "$tab_layout" --name "$name"
    else
      ZELLIJ_SESSION_NAME="$target_session" zellij action new-tab --layout "$tab_layout" --name "$name"
    fi
    echo -e "  ${GREEN}+ $name${NC}"
  done

  echo ""
  if [[ -z "${ZELLIJ:-}" ]]; then
    echo -e "${GREEN}Injection complete. Attach with:${NC}"
    echo -e "  ${BOLD}zellij attach $target_session${NC}"
  else
    echo -e "${GREEN}Injection complete. New tabs are ready.${NC}"
  fi
}

# ─── Launch inside existing Zellij ───
launch_inside_zellij() {
  local project_count=$1

  echo -e "${YELLOW}  Inside Zellij — building workspace in-place...${NC}"
  echo ""

  zellij action rename-session "$SESSION_NAME" 2>/dev/null || true

  # Watcher tab
  local watcher_layout="/tmp/agency-tab-watcher.kdl"
  cat > "$watcher_layout" << KDL_W
layout {
    pane command="bash" {
        args "-c" "$AGENCY_SCRIPTS_DIR/agency-watcher.sh"
    }
}
KDL_W
  zellij action new-tab --layout "$watcher_layout" --name "Watcher"
  echo -e "  ${GREEN}+ Watcher${NC}"

  for i in $(seq 0 $((project_count - 1))); do
    local name tab_layout
    name=$(yq ".projects[$i].name" "$PLAN_FILE")
    tab_layout=$(generate_tab_layout "$i")
    zellij action new-tab --layout "$tab_layout" --name "$name"
    echo -e "  ${GREEN}+ $name${NC}"
  done

  zellij action go-to-tab-name "Watcher" 2>/dev/null || true
  echo ""
  echo -e "${GREEN}  Workspace ready.${NC}"
}

# ─── Main ───
main() {
  echo ""
  echo -e "${CYAN}Agency OS — Dispatch${NC}"
  echo ""

  check_deps
  check_plan

  local project_count
  project_count=$(yq '.projects | length' "$PLAN_FILE")

  if [[ "$project_count" -eq 0 ]]; then
    echo -e "${YELLOW}No projects in plan.${NC}"
    exit 0
  fi

  local inside_zellij=false
  [[ -n "${ZELLIJ:-}" ]] && inside_zellij=true

  echo -e "${BLUE}Plan:${NC}     $PLAN_FILE"
  echo -e "${BLUE}Date:${NC}     $DATE"
  echo -e "${BLUE}Projects:${NC} $project_count"
  echo -e "${BLUE}Mode:${NC}     $AGENCY_PERMISSIONS_MODE"
  if [[ "$inside_zellij" == true ]]; then
    echo -e "${BLUE}Zellij:${NC}   inside active session"
  fi
  echo ""

  detect_active_sessions

  # === INSIDE ZELLIJ ===
  if [[ "$inside_zellij" == true ]]; then
    if [[ "$ACTIVE_SESSION_COUNT" -gt 0 ]]; then
      local current_session
      current_session=$(zellij list-sessions 2>/dev/null | sed $'s/\033\[[0-9;]*m//g' | grep -v EXITED | grep "agency-" | head -1 | awk '{print $1}')
      current_session="${current_session:-unknown}"

      if [[ "$current_session" == "$SESSION_NAME" ]]; then
        detect_new_projects
        if [[ "$NEW_PROJECT_COUNT" -eq 0 ]]; then
          echo -e "${YELLOW}All plan projects already active. Nothing to inject.${NC}"
          exit 0
        fi
        inject_into_session "$current_session"
        exit 0
      else
        echo -e "${YELLOW}Inside Zellij, but session '$current_session' belongs to a different plan.${NC}"
        echo "Open a new terminal (outside Zellij) and run: agency dispatch"
        exit 0
      fi
    else
      echo -e "${BLUE}Inside Zellij — building workspace in current session${NC}"
      echo ""
      prepare_sessions
      echo ""
      launch_inside_zellij "$project_count"
      exit 0
    fi
  fi

  # === OUTSIDE ZELLIJ ===
  local this_session_exists=false
  if [[ "$ACTIVE_SESSION_COUNT" -gt 0 ]]; then
    for s in "${ACTIVE_AGENCY_SESSIONS[@]}"; do
      [[ "$s" == "$SESSION_NAME" ]] && this_session_exists=true && break
    done
  fi

  if [[ "$this_session_exists" == true ]]; then
    echo -e "${YELLOW}Session '$SESSION_NAME' is already running.${NC}"

    detect_new_projects

    if [[ "$NEW_PROJECT_COUNT" -gt 0 ]]; then
      echo "  New projects to inject:"
      for idx in "${NEW_PROJECT_INDICES[@]}"; do
        local pname
        pname=$(yq ".projects[$idx].name" "$PLAN_FILE")
        echo -e "    ${GREEN}+ $pname${NC}"
      done
      echo ""
    fi

    local session_choice=""
    if [[ -t 0 ]]; then
      echo -e "  ${BOLD}1)${NC} Inject new projects ${CYAN}(default)${NC}"
      echo -e "  ${BOLD}2)${NC} Kill & start fresh ${RED}(type KILL to confirm)${NC}"
      echo -e "  ${BOLD}3)${NC} Abort"
      echo -n "  Select [1/2/3]: "
      read -r session_choice
      echo ""
    else
      session_choice="1"
    fi

    case "${session_choice:-1}" in
      1)
        if [[ "$NEW_PROJECT_COUNT" -eq 0 ]]; then
          echo "  No new projects to inject."
          exit 0
        fi
        inject_into_session "$SESSION_NAME"
        exit 0
        ;;
      2)
        echo -n "  Type KILL to confirm: "
        local kill_confirm=""
        [[ -t 0 ]] && read -r kill_confirm
        if [[ "$kill_confirm" != "KILL" ]]; then
          echo "  Aborted."
          exit 0
        fi
        zellij kill-session "$SESSION_NAME" 2>/dev/null || true
        zellij delete-session "$SESSION_NAME" 2>/dev/null || true
        sleep 1
        echo "  Killed '$SESSION_NAME'."
        echo ""
        ;;
      *)
        echo "  Aborted."
        exit 0
        ;;
    esac
  elif [[ "$ACTIVE_SESSION_COUNT" -gt 0 ]]; then
    echo -e "${BLUE}Other agency session(s) running:${NC}"
    if [[ "$ACTIVE_SESSION_COUNT" -gt 0 ]]; then
      for s in "${ACTIVE_AGENCY_SESSIONS[@]}"; do
        echo -e "    $s"
      done
    fi
    echo -e "${GREEN}Launching '$SESSION_NAME' alongside them.${NC}"
    echo ""
  fi

  # === FRESH LAUNCH ===
  # Safety: never reached from inside Zellij
  if [[ -n "${ZELLIJ:-}" ]]; then
    echo -e "${RED}FATAL: Fresh launch blocked — already inside Zellij.${NC}"
    exit 1
  fi

  prepare_sessions
  echo ""

  echo -e "${GREEN}Launching...${NC}"
  echo "  Session: $SESSION_NAME"
  echo "  Tabs:    Watcher + $project_count project(s)"
  echo ""

  local layout_file
  layout_file=$(generate_session_layout "$project_count")

  zellij -s "$SESSION_NAME" -n "$layout_file"
}

main "$@"
