# Code Quality Rules

## Testing
- Run tests before reporting a task as done.
- For UI components: write or run render tests.
- If no test framework exists, write the first tests.
- Never skip failing tests — fix them or report as blocked.

## Type Safety
- Run `tsc --noEmit` (TypeScript) or `mypy` (Python) before committing.
- Fix type errors — don't suppress with `any` or `# type: ignore`.

## Input Validation
- Validate user input on every API endpoint.
- Never expose internal errors to clients.
- Sanitize data at system boundaries (user input, external APIs).

## Lint
- Run the project's linter before committing.
- Fix lint warnings — don't disable rules without justification.
