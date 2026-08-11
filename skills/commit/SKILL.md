---
name: commit
description: "Commit changed files with a minimal, optionally JIRA-prefixed message. Trigger on: '/commit', 'commit this', 'commit my changes'. Detects the issue key from the branch, stages only task-related files, confirms before committing, and analyzes pre-commit hook failures — auto-fixing trivial formatting issues, asking before anything bigger."
disable-model-invocation: true
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git rev-parse:*), Bash(git add:*), Bash(git commit:*), Read, Edit, Grep, AskUserQuestion
---

# Commit

Create a git commit with a minimal commit message. Use subagents for Steps 1–3 only. Follow these steps in order.

## 1. Detect the JIRA issue key

Run these in parallel:
- `git rev-parse --abbrev-ref HEAD` to get the current branch
- `git status` (no `-uall`) to see what's changed
- `git diff` and `git diff --cached` to see the actual changes
- `git log -5 --oneline` to match the repo's commit style

From the branch name, extract a JIRA-style key matching the pattern `[A-Z]+-\d+` (case-insensitive — uppercase it). Examples: `feature/bro-32-foo` → `BRO-32`, `BRO-105/refactor` → `BRO-105`, `feature/uc-1-gtfs-import` → no match.

If the branch yields no key, scan the most recent ~10 user messages in this conversation for a `[A-Z]+-\d+` mention and use the most recent one. If still nothing, proceed without a prefix.

## 2. Decide what to stage

Look at `git status`. If `$ARGUMENTS` lists specific paths, stage only those. Otherwise:
- Stage files that are clearly part of the current task (based on conversation context — what you've been editing).
- **Do NOT stage** unrelated modifications (notebook re-runs, `.gitignore` edits, settings files) unless the user explicitly said to include them. Call them out instead.
- Never use `git add -A` or `git add .`. Stage by explicit path.

## 3. Draft the commit message

Hard rules:
- **First line ≤ 100 characters total**, including the JIRA prefix.
- Format: `BRO-XX <short imperative summary>` if a key was found, else just `<short imperative summary>`.
- Imperative mood ("Add", "Fix", "Refactor"), no trailing period.
- **No body** unless the change is genuinely non-obvious from the diff or carries a constraint a future reader would need (a workaround, a deliberate omission, a follow-up). When unsure, omit the body.
- If you do include a body: one blank line after the subject, then a tight paragraph or 2–3 short bullets. No headings, no co-author trailers, no marketing.

## 4. Confirm before committing

Do not use subagents for this step or Step 5.

Ask the user via `AskUserQuestion` whether to commit or cancel. The dialog must be self-contained — do not rely on text printed before the tool call being visible:

- Put the full drafted commit message in the `preview` field of the **Commit** option.
- List the files you're about to stage, and the files you're deliberately leaving out (with one-line reasons), in the `question` text.
- No separate "edit" option. If the user picks **Commit** with a note attached, apply the note's tweak to the message and commit without re-asking. If they answer via "Other", treat it as redraft instructions: revise and confirm again.

Do not commit until they approve.

## 5. Commit

On approval:
- `git add <explicit paths>`
- `git commit -m "$(cat <<'EOF'
<message>
EOF
)"` — always pass the message via heredoc so multi-line bodies format correctly.
- Run `git status` and report the new HEAD short SHA + summary.

If the commit fails because a hook rejected it, go to Step 6.

## 6. Handle commit hook failures

When `git commit` fails due to a pre-commit or commit-msg hook, do not give up and do not work around it. Analyze first:

1. Read the full hook output and identify the actual cause (formatter, linter, type check, tests, secret scan, message policy, …).
2. Run `git status` and `git diff` again — many hooks (prettier, black, ruff, eslint `--fix`, import sorters) fix files in place and fail only so the changes get re-staged.

Then classify the failure:

### Trivial — fix without asking

Mechanical changes that cannot alter behavior or meaning:
- Whitespace: trailing whitespace, missing EOF newline, line-ending normalization, tabs vs spaces
- Code formatting applied by a formatter (prettier, black, gofmt, rustfmt, …)
- Import sorting / unused-import removal done by an auto-fixer
- Files the hook already modified in place that just need re-staging

For these, apply the fix (or simply re-stage the hook-modified files — only the files that were part of this commit), retry `git commit` with the same message, and briefly report what the hook changed.

### Substantive — ask first

Anything requiring a judgment call or a real code change:
- Lint or type errors that need manual code edits
- Failing tests
- Secret/credential detection findings
- Commit-msg policy rejections (the user approved that exact message — confirm the adjusted message via `AskUserQuestion`, with the new message in the confirm option's `preview`)

For these, summarize the failure in 1–3 lines, state your proposed fix, and ask via `AskUserQuestion` whether to **fix it**, **commit without those changes** (e.g. unstage the offending file, if that makes sense), or **cancel**. Apply the fix only on approval, then retry the commit.

### Hard rules

- Never pass `--no-verify`.
- Never amend — retry as a fresh `git commit` (the failed attempt created no commit).
- If hooks still fail after 2 fix attempts, stop, show the remaining error output, and let the user decide.

## Arguments

`$ARGUMENTS` may contain explicit file paths to stage, or extra context for the commit message. If empty, infer from the conversation.
