---
name: work
description: "Start working on a Jira ticket — fetches issue details via Atlassian MCP, creates a worktree with a properly-named branch, gathers context from Confluence and linked issues, transitions the issue to In Progress, and enters planning mode. Trigger on: '/work BRO-67', '/work TPS-1123', 'start working on BRO-67', 'work on PROJ-42'. Use this skill whenever a Jira issue key is mentioned alongside intent to begin implementation."
---

# Work on a Jira Issue

Fetch a Jira ticket, set up an isolated worktree with a properly-named branch, gather surrounding
context, transition the issue to In Progress, and enter planning mode so implementation starts
from a clear understanding of the problem.

## Step 1: Parse the issue key

Extract a Jira key from `$ARGUMENTS` — the pattern is 1-10 uppercase letters, a dash, then digits
(e.g. `BRO-67`, `TPS-1123`). Match case-insensitively and uppercase the result.

The argument may be:
- Just the key: `BRO-67`
- A URL: `https://triply.atlassian.net/browse/BRO-67`
- A phrase: `work on BRO-67 the GTFS importer`
- A key with flags: `--hotfix BRO-99`

Also check for the `--hotfix` flag — if present, the branch prefix will be `hotfix/` instead of
the default derived from issue type (see Step 4).

If no key is found, ask the user:

> I need a Jira issue key to get started. Example: `/work BRO-67`
>
> What ticket should I work on?

Stop here until a key is provided.

## Step 2: Resolve the Atlassian site

Try passing the site hostname from memory or CLAUDE.md (e.g. `triply.atlassian.net`) as the
`cloudId` parameter. If there is no site hint or the first call fails, call
`getAccessibleAtlassianResources` to list available sites and pick the matching one. If multiple
sites exist and there's ambiguity, ask the user which site to use.

Store the resolved `cloudId` for all subsequent Atlassian calls in this session.

## Step 3: Fetch the issue

```
getJiraIssue(
  cloudId = "<cloudId>",
  issueIdOrKey = "<KEY>",
  responseContentFormat = "markdown"
)
```

If the call fails (wrong project, permissions, typo), report the error and stop.

Extract from the response:
- **Summary** and **description**
- **Status** and **priority**
- **Issue type** (Epic, Task, Bug, etc.)
- **Assignee** and **reporter**
- **Labels**
- **Parent** (epic key, if present)
- **Linked issues** — collect their keys for Step 5

## Step 4: Create worktree and branch

### Determine the branch prefix

| Condition | Prefix |
|-----------|--------|
| `--hotfix` flag was passed | `hotfix/` |
| Issue type is Bug | `bugfix/` |
| Everything else | `feature/` |

### Derive the branch name

Take the issue summary, lowercase it, replace non-alphanumeric characters with hyphens, collapse
consecutive hyphens, trim to ~40 characters at a word boundary, and strip trailing hyphens.

Result: `<prefix>/<KEY>-<slug>`
Example: `feature/BRO-67-split-stop-input-into-separate-dtos`

### Check current state

**Already in a worktree whose branch contains this issue key** (e.g. branch
`feature/BRO-67-...`): Skip worktree creation. Say "Already on a branch for this issue."

**Already in a different worktree**: Do not create a nested worktree. Warn:

> You're in a worktree for a different issue (`<current branch>`).
> I'll gather context but won't create another worktree.
> Consider exiting this worktree first if you want full isolation.

**On the main working tree of a git repo**: Create the worktree:

```bash
git worktree add .claude/worktrees/<key-lower> -b <prefix>/<KEY>-<slug>
```

Then enter it:

```
EnterWorktree(path = ".claude/worktrees/<key-lower>")
```

**Not in a git repo**: Skip worktree creation, note it, and continue.

## Step 4b: Transition to In Progress

Move the Jira issue to "In Progress" so the board reflects that work has started.

1. Call `getTransitionsForJiraIssue` to list available transitions
2. Find one whose name contains "Progress" (case-insensitive)
3. Apply it with `transitionJiraIssue`

Skip silently if:
- The issue is already "In Progress"
- No matching transition exists (the workflow may not have one)

## Step 5: Gather surrounding context

Run these in parallel where possible. The goal is enough context to understand the work without
drowning in information.

### 5a. Parent epic

If the issue has a parent/epic key, fetch it with `getJiraIssue`. Extract the epic's summary,
description, and acceptance criteria to understand where this task fits.

### 5b. Linked issues (up to 5)

For each linked issue key (cap at 5), fetch summary and status. Focus on:
- **Blockers** — these affect sequencing
- **Relates-to** — these share context

If more than 5 links exist, just list the extra keys and offer to fetch on request.

### 5c. Confluence pages

Search for related documentation using Rovo search:

```
search(query = "<issue summary keywords>")
```

From the results, identify the 1-2 most relevant Confluence pages (architecture docs, specs,
use-case descriptions). Fetch their content with `getConfluencePage(contentFormat = "markdown")`.
Only read pages whose titles clearly relate to the issue.

### 5d. Sibling tasks in the epic

If the issue belongs to an epic, fetch siblings to understand scope and sequencing:

```
searchJiraIssuesUsingJql(
  cloudId = "<cloudId>",
  jql = "parent = <epic key> ORDER BY rank ASC",
  fields = ["summary", "status", "priority", "assignee"],
  maxResults = 20
)
```

## Step 6: Present the issue summary

Display a structured summary. Keep it scannable — the user should be able to grasp the full
picture in 30 seconds.

```markdown
## <KEY>: <Summary>

**Type:** Task | **Status:** In Progress | **Priority:** Medium
**Epic:** <EPIC-KEY> — <Epic summary>
**Labels:** use-case-1
**Branch:** `feature/BRO-67-split-stop-input-into-separate-dtos`

### Description

<issue description, trimmed to essentials>

### Context

**Linked Issues:**
- BRO-42 (Blocks this) — "<summary>" — Done
- BRO-55 (Related) — "<summary>" — In Progress

**Confluence:**
- [Page Title](url) — <1-line relevance note>

**Sibling Tasks in Epic:**
- [x] BRO-40 — <summary>
- [ ] **BRO-67 — <this task>** ← current
- [ ] BRO-70 — <summary>

### Open Questions

- <Ambiguity or gap spotted in the ticket>
- <Missing acceptance criteria, unclear scope, dependency risk, etc.>
```

## Step 7: Clarify ambiguities

If the open questions from Step 6 are non-trivial, ask the user about them before planning.
Present questions conversationally — not a formal checklist. For example:

> Before I plan this out, a couple of things:
>
> 1. The ticket says "import GTFS data" but the Confluence spec only covers routes and stops.
>    Should I also handle shapes and frequencies?
>
> 2. BRO-55 is still in progress and may change the Route model. Should I build against the
>    current model or wait?

If the user says "just go" or everything looks clear, move straight to planning.

## Step 8: Enter planning mode

Once context is clear, read the project's CLAUDE.md to understand architecture, packages,
commands, and conventions. Then call `EnterPlanMode` and draft an implementation plan covering:

- **Goal**: one sentence describing "done"
- **Approach**: 2-3 sentences on the technical approach, referencing architecture from CLAUDE.md
- **Steps**: numbered, with specific files/modules affected
- **Files to touch**: list of paths
- **Risks / open items**: anything still uncertain

## Edge cases

### Issue is an Epic
Don't start implementation directly. Instead:
- Fetch all child issues
- Present the epic overview with child task statuses
- Ask which child task to work on
- Re-run the workflow with that child's key

### Issue is already Done
Warn before continuing:

> This issue is marked as Done. Want me to continue anyway, or did you mean a different ticket?

### No Atlassian MCP available
If `getJiraIssue` fails because the Atlassian plugin isn't configured:

> The Atlassian plugin doesn't seem to be available. I can still create a worktree
> and plan from context you provide manually.
>
> What does this ticket involve?

Skip to Step 4 (worktree) using the issue key from the argument, then Step 8 (planning) with
whatever the user provides.
