---
name: discourse-pr
description: Generate a Discourse-style commit message and PR description from current changes
---

Look at the changes made in the current branch compared to the base branch (usually `main`). If we're not on a branch other than `main`, use the changes made in the current conversation session instead.

Also read the Claude Code System Prompt for additional context on what was done and why.

From those changes, generate a **commit message** and **PR description** following these exact Discourse conventions:

## Commit Message Rules

- Use exactly ONE of these uppercase prefixes, followed by a colon and space:
  - `FIX:` — A bug fix
  - `PERF:` — A performance improvement
  - `UX:` — A user interface change
  - `SECURITY:` — A security problem fix
  - `FEATURE:` — An added feature
  - `A11Y:` — An accessibility improvement
  - `I18N:` — Translation updates
  - `MT:` — Changes to migrations tooling
  - `DEV:` — A Discourse internals change that doesn't fit the above
- Use **imperative mood** (e.g., "Add X", "Fix Y") and **sentence case**.
- Wrap code symbols, method names, or file paths in **backticks**.
- Do NOT include a trailing period or a commit body.
- Output a single subject line only.

## PR Description Rules

Immediately after the commit message, output a PR description using exactly this format:

> Previously, [brief description of the old state or issue, in the past tense].
>
> This change [brief description of the change and the effect it has, in the present tense].

Keep both sections extremely brief — ideally one sentence each. You may use markdown if it's useful (e.g. for short code snippets). Focus on the motivation for the change. 'why' is more important than 'what'.

## Constraints

- Never use lowercase "conventional commit" prefixes (e.g., `fix:`, `feat:`).

## Example Output

```
UX: Improve `UserSelector` contrast for dark mode

Previously, the text in the `UserSelector` component was difficult to read on dark backgrounds due to low contrast.

This update changes the text color to use the `--primary-medium` CSS variable, which improves readability.
```

## Steps

1. Determine the diff: run `git diff main...HEAD` (or fall back to session changes).
2. Read through the changed files to understand the purpose of the changes.
3. Pick the single most appropriate prefix based on the nature of the change.
4. Write the commit message subject line.
5. Write the two-sentence PR description.
6. Output both together, ready to copy.
