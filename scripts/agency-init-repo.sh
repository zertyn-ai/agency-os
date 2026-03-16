#!/bin/bash
#
# agency-init-repo.sh
# Initializes a repo with Agency OS security and CI.
# Usage: agency-init-repo.sh [path] [env: hq|lab]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/env.sh"

REPO_PATH="${1:-.}"
ENV_TYPE="${2:-hq}"

cd "$REPO_PATH"
REPO_NAME=$(basename "$(pwd)")

echo ""
echo "Agency OS — Init repo: $REPO_NAME ($ENV_TYPE)"
echo "---"

# 1. Git identity from env
if [[ -n "$AGENCY_GH_USER" ]]; then
  git config user.name "$AGENCY_GH_USER"
  echo "+ Git user -> $AGENCY_GH_USER"
fi

# 2. Gitleaks pre-commit hook
mkdir -p .git/hooks
cat > .git/hooks/pre-commit << 'HOOKEOF'
#!/bin/bash
if command -v gitleaks &>/dev/null; then
  gitleaks git --pre-commit --staged --no-banner
  if [ $? -ne 0 ]; then
    echo "BLOCKED: Secret detected in staged files"
    exit 1
  fi
fi
HOOKEOF
chmod +x .git/hooks/pre-commit
echo "+ Gitleaks pre-commit hook"

# 3. .gitignore security patterns
SECURE_PATTERNS="
# === AGENCY OS SECURITY ===
.env
.env.*
.env.local
.env.production
.env.staging
*.pem
*.key
*.p12
*.p8
*.keystore
*.jks
credentials.json
serviceAccountKey.json
service-account*.json
*.secret
.claude/settings.local.json
"

if grep -q "AGENCY OS SECURITY" .gitignore 2>/dev/null; then
  echo "  .gitignore already secured"
else
  echo "$SECURE_PATTERNS" >> .gitignore
  echo "+ .gitignore secured"
fi

# 4. CI workflows (hq only)
if [[ "$ENV_TYPE" == "hq" ]]; then
  mkdir -p .github/workflows
  cp "$AGENCY_DIR/github/checks.yml" .github/workflows/checks.yml 2>/dev/null || true
  cp "$AGENCY_DIR/github/auto-merge.yml" .github/workflows/auto-merge.yml 2>/dev/null || true
  echo "+ CI workflows installed"
else
  echo "  Skipping CI (lab project)"
fi

# 5. Database detection + CLAUDE.md rules
HAS_DB=false
ls -d prisma/ supabase/ drizzle/ migrations/ 2>/dev/null > /dev/null && HAS_DB=true
if [ -f "package.json" ]; then
  grep -ql "supabase\|prisma\|drizzle\|mongoose\|sequelize\|typeorm\|knex" package.json 2>/dev/null && HAS_DB=true
fi

DB_RULES="

## DATABASE RULES (CRITICAL)
- NEVER run migrations directly. Only CREATE migration files.
- NEVER use DROP TABLE, DROP COLUMN, DROP DATABASE.
- NEVER modify schema without creating a versioned migration.
- ALWAYS use parameterized queries. NEVER concatenate SQL strings.
- The human reviews and runs migrations manually.
"

if $HAS_DB; then
  echo "  Database detected"
  if [ -f CLAUDE.md ]; then
    if ! grep -q "DATABASE RULES" CLAUDE.md; then
      echo "$DB_RULES" >> CLAUDE.md
      echo "+ Database rules added to CLAUDE.md"
    fi
  else
    echo -e "# CLAUDE.md\n\nRead CONTEXT.md for full project context.\n$DB_RULES" > CLAUDE.md
    echo "+ CLAUDE.md created with database rules"
  fi
else
  if [ ! -f CLAUDE.md ]; then
    echo -e "# CLAUDE.md\n\nRead CONTEXT.md for full project context." > CLAUDE.md
    echo "+ CLAUDE.md created"
  fi
fi

# 6. .gitleaks.toml baseline
if [ ! -f .gitleaks.toml ]; then
  cat > .gitleaks.toml << 'GLEOF'
[allowlist]
paths = [
  '''\.env''',
  '''\.env\..*''',
  '''\.claude/''',
  '''dist/''',
  '''build/''',
  '''node_modules/''',
]
GLEOF
  echo "+ .gitleaks.toml created"
fi

echo ""
echo "$REPO_NAME initialized ($ENV_TYPE)"
