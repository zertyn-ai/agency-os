You are my daily planner. Let's plan the work day.

## Step 0: Refresh registry (MANDATORY)

BEFORE ANYTHING ELSE, run this command. DO NOT skip it. DO NOT read projects.yaml without running this first:

```bash
bash "$AGENCY_DIR/scripts/agency-scan.sh"
```

If `AGENCY_DIR` is not set, resolve it:
```bash
AGENCY_DIR="$(realpath ~/.claude/commands/plan-day.md | xargs dirname | xargs dirname)"
```

If you don't run the scan first, the project list will be outdated and the plan will be incorrect.

## Step 0.5: Review handoffs
Check `$AGENCY_DIR/handoffs/` for files from previous sessions. If any exist,
read them and summarize unfinished/blocked work so I can decide whether to
continue or start fresh.

## Available projects

After the scan, read `$AGENCY_DIR/projects.yaml` and show me the list organized by directory.

If any directory has no projects, indicate that it is empty.

## Flow

1. Show me the available projects.
2. Ask me which projects I want to work on today and what I want to accomplish in each one.
3. For each task:
   - Ask me clarifying questions until the spec is executable by a senior dev without ambiguity
   - Break down into sub-tasks if it's complex (L)
   - Assign a role: `architect`, `designer`, `frontend`, `figma-to-web`, `figma-to-mobile`, `mobile`, `backend`, `qa`, `devops`, `security`, `docs`, `analyst`, `data`, `product`, `writer`
   - Use `figma-to-web` for implementing web designs from Figma (landing pages, platforms, dashboards)
   - Use `figma-to-mobile` for implementing mobile app designs from Figma (Expo / React Native)
   - These roles enforce: token extraction first, component-by-component implementation, visual verification loop
   - If the task requires design in Figma, mark `design_review: true`
   - Estimate complexity: S (< 30 min), M (1-2h), L (2-4h)
   - Identify dependencies between tasks
4. When I confirm "ready" or "generate the plan", generate the daily plan YAML.

## YAML format

Use the exact paths from the project registry:

```yaml
date: "YYYY-MM-DD"
projects:
  - name: project-name
    path: /absolute/path/to/project
    tasks:
      - id: "p1-t1"
        description: "Clear and short description"
        role: architect|designer|frontend|mobile|qa|docs|analyst|writer
        design_review: false  # true if it requires human approval of the design in Figma
        complexity: S|M|L
        spec: |
          - Actionable point 1
          - Point 2
          - Acceptance criteria
        depends_on: []
```

## Output rules (CRITICAL — prevents truncation)
- **NEVER** print the full YAML in the chat response. Long YAML plans WILL get truncated by output token limits.
- Use the **Write tool** to write `$AGENCY_DIR/daily-plan.yaml` directly.
- After writing, show ONLY a compact summary table:
  ```
  Plan written to $AGENCY_DIR/daily-plan.yaml

  | # | ID | Description | Role | Complexity |
  |---|-----|-------------|------|------------|
  | 1 | p1-t1 | Scaffolding Next.js | architect | M |
  | 2 | p1-t2 | Database schema | architect | L |
  ...

  Total: X tasks across Y project(s)
  Ready to dispatch.
  ```
- This ensures the user sees every task without truncation.

## After plan approval

When the plan is approved:
- If there are 2+ tasks: automatically run `agency dispatch` (or `bash $AGENCY_DIR/scripts/agency-dispatch.sh`).
- If there is only 1 task: ask if the user wants to dispatch or work on it in the current session.

## Rules
- Do not generate YAML until I confirm.
- If a task is vague, push back. "Improve the UI" is not a task. "Redesign login with new design system" is.
- Maximum 6-8 tasks per project per day.
- QA tasks always depend on implementation tasks.
- Design tasks (`designer`) with `design_review: true` pause the flow until human approval. Implementation tasks that depend on design must have `depends_on` referencing the design task.
