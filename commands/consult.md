# /consult — On-demand expert role consultation

Adopt a specialized Agency OS role for the current task. This gives you access to 17 expert roles without running a full dispatch.

## How to use

1. **Resolve Agency OS path:**
   ```bash
   AGENCY_ROLES_DIR="$(realpath ~/.claude/commands/consult.md 2>/dev/null | xargs dirname 2>/dev/null)/../roles"
   # Fallback if realpath fails
   [ ! -d "$AGENCY_ROLES_DIR" ] && AGENCY_ROLES_DIR="$AGENCY_DIR/roles"
   ls "$AGENCY_ROLES_DIR"/*.md 2>/dev/null | xargs -I{} basename {} .md
   ```

2. **If the user specified a role inline** (e.g. `/consult security`), use that role directly.
   **If no role was specified**, show the available roles and ask the user to pick one.

3. **Read the selected role's `.md` file:**
   ```bash
   cat "$AGENCY_ROLES_DIR/{role}.md"
   ```

4. **Adopt that role's full expertise** for the current task:
   - Follow the role's guidelines, quality gates, and verification steps
   - Apply the role's domain-specific checks (e.g., security → OWASP checks, qa → edge cases)
   - Think and respond as that specialist would

5. **Ask the user** what they'd like help with, then proceed with the role's expertise applied.

## Available roles

- `architect` — System design, project structure, technical decisions
- `frontend` — Web UI, React, CSS, accessibility
- `backend` — APIs, databases, server logic
- `mobile` — React Native, Expo, mobile UX
- `designer` — Figma, design systems, UX
- `figma-to-web` — Figma → web implementation
- `figma-to-mobile` — Figma → mobile implementation
- `qa` — Testing, edge cases, quality assurance
- `security` — OWASP, auth, vulnerability analysis
- `devops` — CI/CD, infrastructure, deployment
- `docs` — Documentation, READMEs, guides
- `analyst` — Data analysis, metrics, reporting
- `data` — Data engineering, pipelines, schemas
- `product` — Product strategy, specs, prioritization
- `writer` — Technical writing, copy, content
- `reviewer` — Code review, PR analysis

Note: `orchestrator` is excluded — it's only for dispatch sessions.
