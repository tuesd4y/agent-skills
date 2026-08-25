---
name: pr
description: "Open a minimal, structured pull request for the current branch. Trigger on: '/pr', 'create a PR', 'open a pull request'. Detects the base branch, stacks on a parent PR via the gh stack extension when the branch builds on one, fills the repo's PR template if one exists, keeps the description short (bullets over prose), confirms title and body before pushing, and reports the PR URL."
disable-model-invocation: true
allowed-tools: Bash(git status:*), Bash(git log:*), Bash(git diff:*), Bash(git rev-parse:*), Bash(git config:*), Bash(git push:*), Bash(gh pr:*), Bash(gh stack:*), Bash(gh extension:*), Bash(gh repo view:*), Bash(*/scripts/gather-pr-context.sh:*), Read, Grep, AskUserQuestion
---

# Pull Request

Open a pull request with a minimal, structured description. Do not use subagents. Follow these steps in order.

## 1. Gather context

Run the bundled script in a single Bash call (the skill's base directory is shown when the skill is invoked):

```
bash <skill-base-dir>/scripts/gather-pr-context.sh
```

It prints the branch, a JIRA key candidate, uncommitted changes, the detected base branch, the stacked-PR setting and any parent PR candidates, push state, commits and diff vs the merge-base (truncated past 400 lines — set `MAX_DIFF_LINES` to raise), any PR templates found in the repo, and whether a PR already exists for this branch.

Stop early with a clear one-line explanation if:
- The current branch **is** the base branch — ask the user to create a branch first.
- There are **no commits** ahead of the base.
- `gh` is unavailable or unauthenticated.

If there are uncommitted changes, call them out and suggest `/commit` first, but don't block — the user may want the PR without them.

If a PR already exists for the branch, skip to Step 5 (update instead of create).

Treat the JIRA key as a candidate, not a fact — same rules as the commit skill: reject non-ticket matches, fall back to a `[A-Z]+-\d+` mention in the recent conversation, else no prefix.

Also judge whether the local branch name is temporary or auto-generated (random word pairs like `lucid-dragon`, worktree names like `wt-1234` or `tmp-*` — anything that doesn't describe the change). If it is, propose a real name for the **remote** branch: `feature/`, `bugfix/`, or `hotfix/` prefix depending on the nature of the change, then the lowercased JIRA key (if any) and a short kebab-case slug — e.g. `feature/bro-32-pr-skill`. The local branch keeps its name; only the branch pushed to the remote is renamed.

## 1b. Stack on a parent PR

When a branch builds on another branch that already has an open PR, the PR should target that
branch and join it in a GitHub **Stack** — otherwise its diff includes the parent's commits.
Stacking is handled by the official `gh stack` extension (`github/gh-stack`), not by hand.

**Only consider stacking when all of these hold** (otherwise skip this step entirely):
- `gh` is available and authenticated.
- The feature is enabled: either `skills.pr.stacked=true` in the script output (set per repo with
  `git config skills.pr.stacked true`, or globally with `--global`), or `$ARGUMENTS` contains
  `stacked`. `$ARGUMENTS` containing `no-stacked` disables it even when the config is on.
- There is a parent to stack on (see below).

### Identify the parent

Read the script's `== STACKED PRs ==` block:

- **`current stack:` has JSON** — the branch is already in a locally tracked stack. The parent is
  the branch directly below the current one (branches are ordered bottom → top, trunk-first);
  its PR number, if any, is in the same JSON. If the current branch is the bottom of the stack,
  the parent is the trunk — that's a normal PR, skip stacking.
- **Otherwise, fall back to `candidates:`** — open PRs whose head branch is an ancestor of `HEAD`.
  Pick the **nearest**: the first row, fewest commits ahead. If there are no candidates, skip
  stacking.

If the chosen parent has 0 commits between it and `HEAD`, the branch has nothing of its own yet —
report that and stop.

### Missing extension

If `gh stack: not installed`, don't install it silently. Offer it as an option in the Step 4
dialog: **Install `gh stack` and stack the PR** (runs `gh extension install github/gh-stack`)
alongside **Create as a plain PR based on `<parent branch>`**. On the plain path, target the
parent branch anyway and add `Stacked on #<parent PR number> — merge that one first.` as the first
line of the body; without the extension nothing else links the two.

### Diff scope

Re-derive commits and diff against the parent, since the script computed them against the default
base:

```bash
git log --oneline <parent-ref>..HEAD
git diff --stat <parent-ref>..HEAD
git diff <parent-ref>..HEAD
```

Use `origin/<parent-head-branch>` as `<parent-ref>` when that remote ref exists, else the local
branch. Title and body describe **only** these commits.

Record the parent branch and PR number for Steps 4 and 5.

## 2. Draft the title

- Imperative mood, no trailing period, ≤ 70 characters including the JIRA prefix.
- Format: `BRO-XX <short imperative summary>` if a key was found, else just the summary.
- Summarize the branch's net effect, not the individual commits.

## 3. Draft the body

Keep it short and structured — bullets over prose, no marketing, no attribution lines, no session links.

Don't hand-write "stacked on #N" links when `gh stack` is in play — GitHub renders the stack
itself. Only add that line on the fallback path described in Step 1b.

**If the script found a PR template:** use it.
- Keep every section and checklist item — don't delete or reorder sections.
- Fill each applicable section with 1–4 short bullets or a single sentence.
- Write "–" in sections that don't apply instead of padding them.
- Tick only checkboxes you can verify from the diff or conversation; leave the rest unticked.
- If multiple templates were found, ask the user via `AskUserQuestion` which one to use.

**If no template exists**, use this structure:

```
<One-sentence summary of what the PR does and why.>

## Changes
- <bullet per logical change, not per commit>

## Notes
- <constraints, deliberate omissions, follow-ups, how to test — omit the section if empty>
```

## 4. Confirm before creating

Ask the user via `AskUserQuestion` whether to create the PR. The dialog must be self-contained — do not rely on text printed before the tool call being visible:

- Put the full title and body in the `preview` field of the **Create PR** option.
- State in the `question` text: the base branch — and, when stacking, that it's the parent PR's
  branch plus that PR's number, and that the PR will be linked into a GitHub Stack via
  `gh stack link`, so the user can veto stacking via a note or "Other" — the number
  of commits, and — if the branch isn't pushed or is ahead of its upstream — that approving will **push the branch** to the remote. If a remote branch name was proposed (temporary local name), state it here too so the user can veto or tweak it via a note.
- Offer a **Create as draft** option (same preview) and **Cancel**.
- No separate "edit" option. If the user picks a create option with a note attached, apply the note's tweak and proceed without re-asking. If they answer via "Other", treat it as redraft instructions: revise and confirm again.

Do not push or create anything until they approve.

## 5. Create or update

On approval:
- Push if needed (only when there's no upstream or the branch is ahead): `git push -u origin <branch>` — or, when a remote branch name was proposed, `git push -u origin <local-branch>:<remote-branch>`.
- Create: `gh pr create --base <base> --title "<title>" --body "$(cat <<'EOF'
<body>
EOF
)"` — always pass the body via heredoc. Add `--draft` if the user chose draft, and `--head <remote-branch>` when the remote branch name differs from the local one. For a stacked PR, `<base>` is the parent branch from Step 1b.
- Report the PR URL — and, for a stacked PR, note that GitHub retargets it to the parent's base
  automatically once the parent PR merges.

### Stacked PRs: link the stack

For a stacked PR, after `gh pr create` succeeds, join it to the parent on GitHub:

```bash
gh stack link <parent PR number> <new PR number>
```

Pass PR numbers, bottom to top, and include every PR already in the parent's stack — `link` is
additive and won't remove PRs, but it needs the full chain in order to set each base correctly. If
the parent was in a tracked stack (`current stack:` JSON from Step 1b), list that stack's PR
numbers in order, then the new one. `link` pushes any unpushed branches, fixes bases that don't
match the chain, and creates or extends the stack on GitHub — it does not touch local `gh stack`
tracking state.

Prefer `gh stack link` over `gh stack submit`: `submit` opens a TUI, and in a non-interactive
terminal it auto-generates titles and creates drafts, discarding the title and body the user just
approved.

Then report the stack: run `gh stack view --short` if the branch is in a tracked stack, otherwise
just list the chained PR numbers with the new one marked.

If the user picked the install option, run `gh extension install github/gh-stack` first. If it
fails, fall back to the plain path from Step 1b (base already targets the parent — just add the
`Stacked on #N` line via `gh pr edit`) and say so.

**If a PR already exists** for the branch: show its current title/state, draft the updated title/body from the branch diff vs its current base, and confirm via the same dialog (option label **Update PR**, preview showing the new title and body). On approval, push if needed and run `gh pr edit` with the new title/body. If stacking applies and the existing PR's base is not the parent branch, include `--base <parent-branch>` and say so in the dialog — then run the same `gh stack link` chain, which also corrects the base on GitHub.

If `gh pr create` fails, show the error verbatim and stop — don't retry with different flags on your own. If `gh stack link` fails, the PR itself already exists: report the URL, show the error verbatim, and leave the linking to the user.

## Arguments

`$ARGUMENTS` may contain a base branch override, the word `draft`, `stacked` / `no-stacked` to force stacking on or off for this run, or extra context for the description. If empty, infer from the conversation. An explicit base branch override wins over stacking.
