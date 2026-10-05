---
name: explain-diff
description: "Explicit invocation only: use /explain-diff or $explain-diff to create a rich, interactive HTML explanation of a code change, diff, branch, or PR. Never activate automatically for general explanation or review requests."
disable-model-invocation: true
---

# Explain Diff

Create a rich, interactive explanation of the specified code change as a single self-contained HTML file. This skill is manual-only: use it only when the user explicitly invokes `explain-diff`.

## Understand the change

Use the invocation arguments or conversation context to identify the diff, commit, branch comparison, or PR. If the target is missing and cannot be inferred, ask which change to explain before generating the file.

Inspect the complete diff and broadly explore the surrounding code: callers, dependencies, data models, tests, and the relevant user flow. Read both the old and new implementations where necessary. For a branch or PR, compare against its intended base using the merge-base and state the comparison in the explanation. Distinguish committed changes from local edits. If the diff is truncated, retrieve the missing parts.

Build the explanation from code evidence. Separate verified behavior from inferred motivation and identify any uncertainty. Explain the change; do not modify the repository or turn the task into an unsolicited code review.

## Required sections

Use these four sections, in this order, on one long page with section headers and an anchor-linked table of contents. Do not use tabs for the top-level structure.

### Background

Explain the existing system relevant to the change in two layers:

- A deep beginner-friendly background that introduces the necessary concepts and the wider system. Make it clearly skippable, for example with a native `<details>` element and a link to the focused background.
- A narrower background that explains the components, contracts, and behavior directly affected by the change.

Use the surrounding code to establish how the system actually works. Define unfamiliar terms and connect the background to the problem the change solves.

### Intuition

Explain the core idea before implementation details. Use concrete examples with small toy data and show the behavior before and after the change. Include figures and diagrams liberally where they clarify the mechanism, and explain why the new approach produces the intended result.

### Code

Walk through the changes at a high level, grouped and ordered by conceptual dependencies or user flow rather than raw diff order. Connect each group to the intuition and relevant behavior. Include representative code excerpts with file paths and revision-appropriate line references when available. Explain important edge cases, tradeoffs, and relevant tests without reproducing the entire diff.

### Quiz

Write exactly five medium-difficulty multiple-choice questions that test substantive understanding of the change. Avoid trivia and gotchas. Use plausible distractors based on misunderstandings of the mechanism, behavior, or edge cases.

Make every question interactive. When the reader selects an answer, immediately indicate whether it is correct and give explanatory feedback, including why the chosen answer succeeds or fails. Allow the reader to try again. Use accessible buttons or radio controls and announce feedback with `aria-live`; do not communicate correctness through color alone.

## Writing and visual design

Write with clear reasoning, concrete examples, engaging classic prose, and smooth transitions—the clarity and flow requested in the Martin Kleppmann reference. Introduce ideas in the order the reader needs them, and explain why each detail matters.

Choose a small number of reusable diagram families so the reader can compare cases easily. Useful options include simplified representations of the app UI and system diagrams showing data flow or component communication with example data on the connections.

Use simple HTML/CSS designs or inline SVG for diagrams, and semantic HTML lists for collections. Do not use ASCII diagrams. Add callouts for key concepts, definitions, important edge cases, and assumptions.

## Output requirements

- Produce a single HTML file with all CSS and JavaScript inline. It must work offline without remote fonts, libraries, images, or other dependencies.
- Include a descriptive title, the change being explained, and the exact comparison or revision identifiers used.
- Use responsive styling, readable typography, visible keyboard focus, and layouts that remain usable on a phone. Let wide code blocks scroll without widening the whole page.
- Use `<pre><code>` for code blocks and HTML-escape source code. Explicitly set `white-space: pre` or `white-space: pre-wrap` for every code block. If a custom styled element is necessary instead, its CSS must use `white-space: pre-wrap`.
- Save the file outside the repository in a global location on the computer, normally `/tmp/`. Determine today's date at execution time in the user's local timezone. Every filename must start with `YYYY-MM-DD-`, for example `/tmp/2026-01-12-explanation-cache-invalidation.html`. Use a descriptive slug and avoid overwriting an unrelated existing explanation.

## Verify and deliver

Before saving the final file, scan every code block in the HTML source and confirm its applicable CSS sets `white-space: pre` or `pre-wrap`. Check that all four sections and table-of-contents targets exist, exactly five quiz questions have correct answers and explanatory feedback, and there are no external asset dependencies.

If browser tooling is available, open the file and check navigation, quiz feedback for both correct and incorrect answers, keyboard interaction, and a narrow viewport. Fix any layout or interaction problems found. Otherwise, validate the HTML structure and JavaScript as far as available tools permit and state any verification limitation briefly.

Return a clickable link to the completed HTML file and identify the change it explains.
