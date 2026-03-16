# /context-init — Generate CONTEXT.md for a project

When the user runs /context-init, analyze the entire codebase and generate a comprehensive CONTEXT.md file.

## Steps

### 1. Scan the project
```bash
find . -type f -not -path './node_modules/*' -not -path './.git/*' -not -path './dist/*' -not -path './build/*' -not -path './.next/*' | head -200
cat package.json 2>/dev/null || cat pyproject.toml 2>/dev/null || cat requirements.txt 2>/dev/null
ls -la tsconfig.json next.config.* vite.config.* tailwind.config.* .eslintrc* 2>/dev/null
```

### 2. Generate CONTEXT.md with this structure

The file must include these sections:

**Header:** Project name and one paragraph description.

**Tech Stack:** Framework, language, styling, state management, database, auth, payments, deployment. Be specific about versions.

**Project Structure:** Directory tree with brief explanation of each important directory.

**Key Patterns:** How routing works, data flow, auth implementation, payment flow, custom conventions.

**Environment Variables:** List all required env vars WITHOUT values.

**Important Commands:** dev, build, test, lint commands.

**Current State:** What works, what is in progress, known issues.

**Architecture Decisions:** Why specific tools were chosen, trade-offs.

### 3. Create symlink for Claude Code

After creating CONTEXT.md, ensure CLAUDE.md exists and references it:
```bash
if [ ! -f CLAUDE.md ]; then
  echo -e "# CLAUDE.md\n\nRead CONTEXT.md for full project context." > CLAUDE.md
fi
```

### 4. Verify
```bash
echo "CONTEXT.md generated ($(wc -l < CONTEXT.md) lines)"
```

## IMPORTANT RULES
- NEVER include actual secret values in CONTEXT.md
- DO include env var names with empty values
- Be specific about versions (not just "React" but "React 18.2")
- Include monorepo structure if applicable
