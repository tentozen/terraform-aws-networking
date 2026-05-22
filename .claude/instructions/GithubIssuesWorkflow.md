# GitHub Issues Workflow

This document defines the GitHub Issues workflow for using it as issue tracker.

## Setup

### Required Labels

Create these labels on the GitHub repo to support structured tracking:

**Issue Types:**
| Label | Color | Description |
|-------|-------|-------------|
| `type:bug` | `#d73a4a` | Something broken that needs fixing |
| `type:feature` | `#0075ca` | New functionality |
| `type:task` | `#0e8a16` | Work item (tests, docs, refactoring) |
| `type:epic` | `#5319e7` | Large feature composed of multiple issues |
| `type:chore` | `#fbca04` | Maintenance work (dependencies, tooling) |

**Priorities:**
| Label | Color | Description |
|-------|-------|-------------|
| `priority:P0` | `#b60205` | Critical (security, data loss, broken builds) |
| `priority:P1` | `#d93f0b` | High (major features, important bugs) |
| `priority:P2` | `#f9d0c4` | Medium (nice-to-have features, minor bugs) |
| `priority:P3` | `#c5def5` | Low (polish, optimization) |
| `priority:P4` | `#bfdadc` | Backlog (future ideas) |

**Status (optional, for board views):**
| Label | Color | Description |
|-------|-------|-------------|
| `status:in_progress` | `#1d76db` | Actively being worked on |

**Area pointers (create as needed):**
Use `area:*` labels for cross-cutting filters, e.g.: `area:frontend`, `area:backend`.

### Label Conventions

- Use `type:*` and `priority:*` labels on every issue.
- Use `type:epic` label and task lists in body for parent-child relationships.
- Use `Related to #X` or `Discovered while working on #X` in issue body for soft relationships.

### Bootstrap Labels

Run this once to create all labels:

```bash
# Types
gh label create "type:bug" --color "d73a4a" --description "Something broken that needs fixing"
gh label create "type:feature" --color "0075ca" --description "New functionality"
gh label create "type:task" --color "0e8a16" --description "Work item (tests, docs, refactoring)"
gh label create "type:epic" --color "5319e7" --description "Large feature composed of multiple issues"
gh label create "type:chore" --color "fbca04" --description "Maintenance work (dependencies, tooling)"

# Priorities
gh label create "priority:P0" --color "b60205" --description "Critical (security, data loss, broken builds)"
gh label create "priority:P1" --color "d93f0b" --description "High (major features, important bugs)"
gh label create "priority:P2" --color "f9d0c4" --description "Medium (nice-to-have features, minor bugs)"
gh label create "priority:P3" --color "c5def5" --description "Low (polish, optimization)"
gh label create "priority:P4" --color "bfdadc" --description "Backlog (future ideas)"

# Status
gh label create "status:in_progress" --color "1d76db" --description "Actively being worked on"
```

---

## Essential Commands

All commands use the [GitHub CLI (`gh`)](https://cli.github.com/).

### Finding Work

```bash
# Show issues ready to work (open, not blocked)
gh issue list -S "-is:blocked"

# All open issues
gh issue list

# Your active work (assigned to you, in progress)
gh issue list --assignee @me --label "status:in_progress"

# View issue details
gh issue view <number>

# Search issues by keyword
gh issue list -S "query"

# Filter by type
gh issue list --label "type:bug"

# Filter by priority
gh issue list --label "priority:P0"

# Combined filters
gh issue list --label "type:bug" --label "priority:P1"
```

### Creating Issues

```bash
# Basic issue creation
gh issue create --title "Summary of this issue" \
  --body "Why this issue exists and what needs to be done" \
  --label "type:task" --label "priority:P2"

# Bug
gh issue create --title "Fix payment timeout" \
  --body "Description of the bug and expected behavior" \
  --label "type:bug" --label "priority:P1"

# Feature
gh issue create --title "Add user authentication" \
  --body "Description of the feature" \
  --label "type:feature" --label "priority:P2"

# Epic (then add sub-issues via API — see Sub-Issues section)
gh issue create --title "Epic: Redesign checkout flow" \
  --body "Redesign the checkout flow for better conversion" \
  --label "type:epic" --label "priority:P1"
```

### Updating Issues

```bash
# Claim work (assign yourself and mark in progress)
gh issue edit <number> --add-assignee @me --add-label "status:in_progress"

# Add a comment (equivalent to bd update --notes)
gh issue comment <number> --body "Found the root cause, fix incoming"

# Update title
gh issue edit <number> --title "New title"

# Update body/description
gh issue edit <number> --body "Updated description"

# Change priority
gh issue edit <number> --remove-label "priority:P2" --add-label "priority:P1"

# Mark as blocked by another issue (use GraphQL — see Dependencies section)
# Unblocking happens automatically when the blocking issue is closed
```

### Closing Issues

```bash
# Close a single issue
gh issue close <number>

# Close with a comment (equivalent to bd close --reason)
gh issue close <number> --comment "Completed in commit abc123"

# Close multiple issues
gh issue close 1 2 3

# Reopen if closed by mistake
gh issue reopen <number>
```

---

## Sub-Issues (Parent-Child)

GitHub has **native sub-issues** support. Use the `addSubIssue` GraphQL mutation to link child issues to a parent (e.g., epic → tasks).

### Adding Sub-Issues

```bash
# Get node IDs for parent and child
PARENT_ID=$(gh issue view <parent-number> --json id --jq '.id')
CHILD_ID=$(gh issue view <child-number> --json id --jq '.id')

# Add child as sub-issue of parent
gh api graphql -f query="
  mutation {
    addSubIssue(input: {
      issueId: \"$PARENT_ID\"
      subIssueId: \"$CHILD_ID\"
    }) {
      issue { id }
      subIssue { id }
    }
  }
"
```

### Removing Sub-Issues

```bash
gh api graphql -f query="
  mutation {
    removeSubIssue(input: {
      issueId: \"$PARENT_ID\"
      subIssueId: \"$CHILD_ID\"
    }) {
      issue { id }
    }
  }
"
```

### Searching Sub-Issues

```bash
# Issues that have a parent
gh issue list -S "has:parent"

# Issues that have sub-issues
gh issue list -S "has:sub-issue"

# Sub-issues of a specific issue
gh issue list -S "parent-issue:<number>"
```

---

## Dependencies and Blocking

GitHub Issues has **native dependency support** (GA August 2025). Issues can be marked as "blocked by" or "blocking" other issues via API, with up to 50 linked issues per relationship type.

### Adding Dependencies

```bash
# Get node IDs for the issues
gh issue view <number> --json id --jq '.id'

# Mark issue as blocked by another issue (GraphQL)
# issueId = the issue that IS blocked, blockingIssueId = the issue that blocks it
gh api graphql -f query='
  mutation {
    addBlockedBy(input: {
      issueId: "<node_id_of_blocked_issue>"
      blockingIssueId: "<node_id_of_blocking_issue>"
    }) {
      clientMutationId
    }
  }
'
```

### Searching by Dependency Status

```bash
# All blocked issues (waiting on something)
gh issue list -S "is:blocked"

# All blocking issues (preventing others from proceeding)
gh issue list -S "is:blocking"

# Issues blocked by a specific issue
gh issue list -S "blocked-by:<number>"

# Issues that a specific issue is blocking
gh issue list -S "blocking:<number>"
```

These filters work in both the repository Issues tab and GitHub Projects.

### Relationship Types

| Relationship | How to Express |
|---|---|
| **Blocks** (hard dependency) | Native: `addBlockedBy` GraphQL mutation |
| **Related** (soft relationship) | `Related to #X` in issue body or comment |
| **Parent-child** (epic/subtask) | Native: `addSubIssue` GraphQL mutation |
| **Discovered-from** | `Discovered while working on #X` in issue body |

Only native **blocked by / blocking** relationships affect the dependency graph. Use `is:blocked` to filter issues that aren't ready for work.

---

## Common Workflows

### Starting Work

Claim every issue you work on — including sub-issues, not just the parent.

```bash
gh issue list -S "-is:blocked"                     # Find available work
gh issue view <number>                             # Review issue details
gh issue edit <number> --add-assignee @me \
  --add-label "status:in_progress"                 # Claim it
git checkout -b feat/<number>-brief-description    # Create branch
```

### Completing Work

Every close MUST remove the `status:in_progress` label. Stale labels pollute filtered views.

```bash
gh issue close <number> --comment "Done in <commit>"              # Close issue
gh issue edit <number> --remove-label "status:in_progress"        # Remove status label
git add . && git commit -m "feat(scope): description (#<number>)"
git push                                                           # Push to remote
```

### Creating Dependent Work

```bash
# Create the dependency first
gh issue create --title "Implement feature X" \
  --body "Description" \
  --label "type:feature" --label "priority:P2"
# Note the issue number (e.g., #20)

# Create the dependent issue
gh issue create --title "Write tests for X" \
  --body "Depends on #20 (need feature X implemented first)" \
  --label "type:task" --label "priority:P2"
# Note the issue number (e.g., #21)

# Link the dependency via GraphQL
ISSUE_ID=$(gh issue view 21 --json id --jq '.id')
BLOCKING_ID=$(gh issue view 20 --json id --jq '.id')
gh api graphql -f query="
  mutation {
    addBlockedBy(input: {
      issueId: \"$ISSUE_ID\"
      blockingIssueId: \"$BLOCKING_ID\"
    }) {
      clientMutationId
    }
  }
"
```

### Filing Discoveries During Work

```bash
gh issue create --title "Found: unexpected null in user profile" \
  --body "Discovered while working on #15. Details..." \
  --label "type:bug" --label "priority:P2"
```

---

## Quick Reference

| Action | Command |
|--------|---------|
| Find unblocked work | `gh issue list -S "-is:blocked no:assignee"` |
| List all open issues | `gh issue list` |
| My active work | `gh issue list --label "status:in_progress"` |
| View issue details | `gh issue view <number>` |
| Create issue | `gh issue create --title "Title" --label "type:task" --label "priority:P2"` |
| Claim work | `gh issue edit <number> --add-assignee @me --add-label "status:in_progress"` |
| Add notes | `gh issue comment <number> --body "..."` |
| Complete work | `gh issue close <number> --comment "Done" && gh issue edit <number> --remove-label "status:in_progress"` |
| Search issues | `gh issue list -S "query"` |
| List blocked | `gh issue list -S "is:blocked"` |
| List blocking | `gh issue list -S "is:blocking"` |
| Add sub-issue | See Sub-Issues section (GraphQL `addSubIssue`) |
| List sub-issues | `gh issue list -S "parent-issue:<number>"` |
| Project stats | `gh issue list --state all --json state --jq 'group_by(.state) \| map({state: .[0].state, count: length})'` |

---

## Branch Naming with Issue Numbers

Reference issue numbers in branch names for traceability:

```
feat/42-add-user-auth
fix/56-payment-timeout
docs/63-api-documentation
```

## Auto-Close Issues via Commits

GitHub auto-closes issues when commits or PRs use these keywords:

```
fixes #42
closes #42
resolves #42
```

Example commit:
```
feat(auth): add JWT refresh token rotation (fixes #42)
```

---

