# /permissions — Show current environment permissions

When the user or orchestrator runs /permissions, display the current permission matrix.

## Check profile
```bash
AGENCY_DIR="$(realpath ~/.claude/commands/permissions.md 2>/dev/null | xargs dirname 2>/dev/null)/.."
[ ! -d "$AGENCY_DIR/config" ] && AGENCY_DIR="$HOME/.agency"
PROFILE=$(grep "^AGENCY_PROFILE=" "$AGENCY_DIR/config" 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "production")
PERMS=$(grep "^AGENCY_PERMISSIONS_MODE=" "$AGENCY_DIR/config" 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "standard")
echo "Profile: $PROFILE | Permissions: $PERMS"
```

## Standard Mode

ALLOWED:
- Read any file in the project
- Create/edit files in src/, components/, lib/, services/, types/, styles/
- Create/edit test files
- Create/edit documentation (README, CONTEXT.md, CLAUDE.md, CHANGELOG)
- Run dev server, build, test, lint
- Create git branches
- Commit and push to feature branches
- Create PRs via gh CLI
- Install npm packages (devDependencies only without approval)

REQUIRES HUMAN APPROVAL:
- Install new production dependencies
- Modify package.json scripts
- Modify CI/CD workflows (.github/)
- Modify config files (next.config, vite.config, tsconfig, etc.)
- Modify environment variable schemas
- Run database migrations
- Add new API routes that handle auth or payments

FORBIDDEN:
- Push to main
- Merge PRs
- Deploy to production (vercel, netlify, eas)
- Modify .env files
- Access ~/.ssh/ or system files
- Run destructive git commands (force push, reset --hard)
- Execute DROP/TRUNCATE/DELETE FROM on databases
- Publish packages (npm publish, etc.)
- Modify security rules or hooks
- Bypass gitleaks or pre-commit hooks

## YOLO Mode

Same as standard mode EXCEPT:
- Uses --dangerously-skip-permissions for Claude Code
- Zero permission prompts — maximum speed
- Best for experiments and personal projects
- Safety hooks (block-dangerous.sh) still run as guardrails
