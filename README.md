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