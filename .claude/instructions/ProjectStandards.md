## Project Standards

### Git Workflow

#### Branching

- ALWAYS create a feature branch before making any changes. Never commit directly to `master` or `main`.

```bash
git checkout main
git pull origin main
git checkout -b type/TICKET-ID-brief-description
```

Branch naming: `type/TICKET-ID-brief-description`

Examples:
```
feat/PROJ-123-add-user-auth
fix/PROJ-456-payment-timeout
docs/PROJ-789-api-documentation
refactor/PROJ-101-extract-billing-service
```

#### Commits

- Use conventional commits format: `type(scope): description`
  - types: feat, fix, docs, style, refactor, test, chore

```
feat(auth): add JWT refresh token rotation
fix(payments): handle gateway timeout on callback
docs(api): add authentication endpoint examples
refactor(orders): extract discount calculation to service
test(users): add specs for profile update
chore(deps): bump rails to 7.2
style(lint): fix rubocop offenses in models
```

#### Atomic commits

- Make atomic commits: group logically related changes together
  - Each commit should represent one coherent unit of change
  - If changes serve different purposes, split them into separate commits
  - Ask yourself: "Would this make sense to revert independently?"

Good — two separate commits:
```
feat(auth): add login endpoint
feat(auth): add password reset flow
```

Bad — unrelated changes lumped together:
```
feat(auth): add login endpoint and fix payment bug and update readme
```


## SDLC Process

### Ticket-Driven Work

ALWAYS work off a ticket. No random or ad-hoc work.

Before starting any task:
1. Confirm a ticket exists for the work
2. If no ticket exists, create one first and get it acknowledged
3. Reference the ticket ID in branch names and commit messages

### Atomic Tickets

One concern per ticket. If a task has independent parts, create separate tickets.
Ask yourself: "Would this make sense to close independently?"

Good — two separate tickets:
```
"Fix: closing workflow doesn't remove status label"
"Fix: label color mismatches between config files"
```

Bad — unrelated concerns in one ticket:
```
"Fix status label cleanup and align label colors and add new guidance"
```


## Issue Tracking

- This project uses **GitHub Issues** for issue tracking via the `gh` CLI.
- No markdown TODOs or local trackers.
- See `GithubIssuesWorkflow.md` for full workflow guidance, label conventions, and dependency management.


**Quick reference:**

| Action | Command |
|--------|---------|
| Find unblocked work | `gh issue list -S "-is:blocked"` |
| View issue details | `gh issue view <number>` |
| Create issue | `gh issue create --title "Title" --label "type:task" --label "priority:P2"` |
| Claim work | `gh issue edit <number> --add-assignee @me --add-label "status:in_progress"` |
| Add notes | `gh issue comment <number> --body "..."` |
| Complete work | `gh issue close <number> --comment "Done" && gh issue edit <number> --remove-label "status:in_progress"` |
| Add sub-issue | Get node IDs with `gh issue view <N> --json id --jq '.id'`, then `addSubIssue` GraphQL mutation (see `GithubIssuesWorkflow.md`) |
| List sub-issues | `gh issue list -S "parent-issue:<number>"` |


## Key Rules

- **Claim before working**: `gh issue edit <number> --add-assignee @me --add-label "status:in_progress"` — applies to ALL issues including sub-issues, not just the parent
- **Remove status on close**: Every `gh issue close` must be followed by `gh issue edit <number> --remove-label "status:in_progress"`
- **File discoveries immediately**: `gh issue create --title "Found: ..." --label "type:bug" --label "priority:P2"`
- **Commit with issue number**: `git commit -m "fix(scope): fix bug (#42)"`


## Coding Methodology

### Verify-First Loop

NEVER write code without a plan to verify it. Follow this loop for every change:

1. **State verification**: Before writing any code, state how you will verify
   the change works (test, bash command, curl, browser check, etc.)
2. **Write verification first**: Write the test or verification step before
   the implementation
3. **Implement**: Write the code to make the verification pass
4. **Run and iterate**: Execute the verification. If it fails, read the error,
   fix the issue, and re-run. Repeat until it passes.

Do NOT move on to the next task until the current change is verified working.

Example workflow:
```
Task: Add a health check endpoint

1. Verification plan: "I'll curl /health and expect a 200 with { status: ok }"
2. Write test first:
   - Request spec: GET /health → assert 200, assert body matches
3. Implement:
   - Add route, add controller action
4. Run: docker compose exec web rails test test/controllers/health_controller_test.rb
   - If red → read error → fix → re-run
   - If green → done, commit
```
