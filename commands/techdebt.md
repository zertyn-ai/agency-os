Scan the current project's codebase and generate a technical debt report.

## What to look for

1. **Duplicate code:** Functions, components, or blocks that do the same or nearly the same thing in different files.
2. **Dead code:** Functions, variables, exports, or components that nobody imports or uses.
3. **Unused imports:** Imports that are not referenced in the file.
4. **Forgotten TODOs and FIXMEs:** Comments like TODO, FIXME, HACK, XXX that have been sitting there for a while.
5. **Pattern inconsistencies:** If the project uses one pattern in one place and solves the same problem differently elsewhere (e.g., fetch vs axios, different error handling approaches, etc.)
6. **Unused dependencies:** Packages in package.json / requirements.txt that are not imported in any file.

## Output

For each issue found, report:
- **Type:** (duplicate | dead | import | todo | inconsistency | dependency)
- **File(s):** affected path(s)
- **Description:** what you found, in 1 line
- **Suggested action:** what to do (remove, consolidate, refactor)
- **Impact:** low | medium | high

Sort by impact (high first).

## Rules
- Report only. DO NOT make changes automatically.
- Ignore node_modules, .git, dist, build, .next, __pycache__.
- If the project has fewer than 10 code files, state so and finish quickly.
- Be specific. "There is duplicate code" is useless. "src/utils/format.ts:23 and src/helpers/string.ts:45 do the same thing" is useful.
- Maximum 15 issues. If there are more, prioritize the high impact ones.
