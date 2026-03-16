# /promote — Promote a lab project to production

When the user runs /promote, run this checklist to verify the project is ready.

## Automated Checks

Run each and report pass/fail:

1. `gitleaks detect --source . --no-git --no-banner` → no leaks
2. `npm audit --audit-level=moderate 2>/dev/null` → no high/critical vulns
3. `npm test 2>/dev/null || pytest 2>/dev/null` → tests pass
4. `npm run build 2>/dev/null` → build succeeds
5. `test -f CONTEXT.md` → exists
6. `test -f CLAUDE.md` → exists
7. `grep -q "AGENCY OS SECURITY" .gitignore` → secured
8. No hardcoded keys in source (grep for sk_live, sk_test, api_key patterns)
9. `test -f .github/workflows/checks.yml` → CI present
10. `test -f .env.example` → env template exists

## Report Format
```
🔍 Promotion Check: {project-name}
═══════════════════════════════════
✅/❌ Secret scan
✅/❌ Security audit
✅/❌ Tests
✅/❌ Build
✅/❌ CONTEXT.md
✅/❌ CLAUDE.md
✅/❌ .gitignore
✅/❌ No hardcoded keys
✅/❌ CI workflows
✅/⚠️ .env.example

Result: READY / NOT READY / READY WITH WARNINGS
```

## If READY

Tell the user:
1. Move or copy the repo to your production projects directory
2. Run `agency init` in the new location
3. Configure production env vars in platform
4. Review and run pending migrations manually

## IMPORTANT
- This command only CHECKS. Never modifies files.
- The human makes the final decision.
