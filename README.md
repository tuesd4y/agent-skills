# Agent Skills

A collection of skills for AI coding agents. Skills are packaged instructions and scripts that extend agent capabilities.

Skills follow the [Agent Skills](https://agentskills.io/) format.

## Available Skills

### translate
Automated translation workflow for Angular i18n XLF files. Finds new translations in changed files, provides context, and generates translations for review.

  Use when:
  - After extracting new i18n strings (nx run <app>:extract-i18n)
  - When `messages.{lang}.xlf` files have `state="new"` entries
  - Before committing translation file changes
  - Translating to German, French, Spanish, or Hungarian

  Workflow:
  1. Detects changed `messages.*.xlf` files via git
  2. Extracts entries with `<target state="new">`
  3. Finds source context (TypeScript `$localize`, HTML `i18n` attributes)
  4. Proposes translation with context for review
  5. Applies approved translations with `state="ai"` marker

  Features:
  - Placeholder preservation (interpolations, HTML tags, line breaks)
  - Language detection from filename pattern
  - Code context lookup for translation IDs
  - Common translation patterns for each language
  - Batch processing with summaries


### commit
Commit changed files with a minimal, optionally JIRA-prefixed message. Runs on Sonnet in Claude Code.

  Use when:
  - Committing finished work (`/commit`, optionally with file paths or extra context)
  - You want a tight, review-friendly commit message without boilerplate

  Workflow:
  1. Detects the JIRA issue key from the branch name (falls back to conversation context)
  2. Stages only task-related files by explicit path (never `git add -A`)
  3. Drafts a minimal imperative commit message (≤ 100 chars, body only when needed)
  4. Confirms files and message with the user before committing
  5. On commit hook failures: auto-fixes trivial issues (whitespace, formatting, re-staging
     hook-modified files) and retries; asks before substantive fixes (lint/type errors,
     failing tests, message policy). Never uses `--no-verify`.


### work
Start working on a Jira ticket end-to-end. Fetches issue details via Atlassian MCP, creates a worktree with a properly-named branch, gathers context, and enters planning mode.

  Use when:
  - Starting work on a Jira ticket (`/work BRO-67`)
  - Bootstrapping a feature, bugfix, or hotfix from a ticket

  Workflow:
  1. Parses the Jira issue key from arguments (supports bare keys, URLs, `--hotfix` flag)
  2. Fetches issue details, description, and linked issues via Atlassian MCP
  3. Creates a git worktree with a conventionally-named branch (`feature/`, `bugfix/`, or `hotfix/`)
  4. Transitions the issue to "In Progress"
  5. Gathers context: parent epic, linked issues, Confluence pages, sibling tasks
  6. Presents a structured summary with open questions
  7. Clarifies ambiguities, then enters plan mode

  Requirements:
  - Atlassian MCP plugin configured with Jira access


## Installation

```bash
npx skills add tuesd4y/agent-skills
```

## Usage

Skills are automatically available once installed. The agent will use them when relevant tasks are detected.

**Examples:**
```
Translate the new translations
```
Or you can manually call the skill e.g. in claude code

`/translate`

## Skill Structure

Each skill contains:
- `SKILL.md` - Instructions for the agent
- `scripts/` - Helper scripts for automation (optional)
- `references/` - Supporting documentation (optional)

## License

MIT