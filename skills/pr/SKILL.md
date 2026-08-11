---
name: pr
description: "Open a minimal, structured pull request for the current branch. Trigger on: '/pr', 'create a PR', 'open a pull request'. Detects the base branch, fills the repo's PR template if one exists, keeps the description short (bullets over prose), confirms title and body before pushing, and reports the PR URL."
disable-model-invocation: true
allowed-tools: Bash(git status:*), Bash(git log:*), Bash(git diff:*), Bash(git rev-parse:*), Bash(git push:*), Bash(gh pr:*), Bash(gh repo view:*), Bash(*/scripts/gather-pr-context.sh:*), Read, Grep, AskUserQuestion
---

# Pull Request

Open a pull request with a minimal, structured description. Do not use subagents. Follow these steps in order.

## 1. Gather context

Run the bundled script in a single Bash call (the skill's base directory is shown when the skill is invoked):

```
bash <skill-base-dir>/scripts/gather-pr-context.sh
```

It prints the branch, a JIRA key candidate, uncommitted changes, the detected base branch, push state, commits and diff vs the merge-base (truncated past 400 lines — set `MAX_DIFF_LINES` to raise), any PR templates found in the repo, and whether a PR already exists for this branch.

Stop early with a clear one-line explanation if:
- The current branch **is** the base branch — ask the user to create a branch first.
- There are **no commits** ahead of the base.
- `gh` is unavailable or unauthenticated.

If there are uncommitted changes, call them out and suggest `/commit` first, but don't block — the user may want the PR without them.

If a PR already exists for the branch, skip to Step 5 (update instead of create).

Treat the JIRA key as a candidate, not a fact — same rules as the commit skill: reject non-ticket matches, fall back to a `[A-Z]+-\d+` mention in the recent conversation, else no prefix.

## 2. Draft the title

- Imperative mood, no trailing period, ≤ 70 characters including the JIRA prefix.
- Format: `BRO-XX <short imperative summary>` if a key was found, else just the summary.
- Summarize the branch's net effect, not the individual commits.

## 3. Draft the body

Keep it short and structured — bullets over prose, no marketing, no attribution lines, no session links.

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
- State in the `question` text: the base branch, the number of commits, and — if the branch isn't pushed or is ahead of its upstream — that approving will **push the branch** to the remote.
- Offer a **Create as draft** option (same preview) and **Cancel**.
- No separate "edit" option. If the user picks a create option with a note attached, apply the note's tweak and proceed without re-asking. If they answer via "Other", treat it as redraft instructions: revise and confirm again.

Do not push or create anything until they approve.

## 5. Create or update

On approval:
- Push if needed: `git push -u origin <branch>` (only when there's no upstream or the branch is ahead).
- Create: `gh pr create --base <base> --title "<title>" --body "$(cat <<'EOF'
<body>
EOF
)"` — always pass the body via heredoc. Add `--draft` if the user chose draft.
- Report the PR URL.

**If a PR already exists** for the branch: show its current title/state, draft the updated title/body from the full branch diff, and confirm via the same dialog (option label **Update PR**, preview showing the new title and body). On approval, push if needed and run `gh pr edit` with the new title/body.

If `gh pr create` fails, show the error verbatim and stop — don't retry with different flags on your own.

## Arguments

`$ARGUMENTS` may contain a base branch override, the word `draft`, or extra context for the description. If empty, infer from the conversation.
