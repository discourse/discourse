# Standardize one rspec spec file against the writing guidelines

You are running ONE iteration of an automated standardization loop. Your job:
take a single rspec spec file and bring it into compliance with the Discourse
writing-rspec-tests guidelines, *without* changing what the file tests.

## Inputs

You will be given:

- An iteration directory path (positional arg).
- An environment variable `TARGET_FILE` — the absolute path of the spec file
  to standardize for this iteration.
- The full guidelines content is at
  `.skills/discourse-writing-rspec-tests/SKILL.md` (read it every iteration —
  it's authoritative).
- The style-guide reference at
  `.skills/discourse-writing-rspec-tests/references/rspec-style-guide.md`,
  plus the type-specific references for request specs, system tests, theme
  tests, and tracking helpers. Read whichever apply to the target file.

## Procedure

1. **Read the guidelines.** Both `SKILL.md` and any relevant references for
   this file's type (model / service / job / request / system / etc.).
2. **Read the target file.**
3. **Identify deviations** from the guidelines. Be specific: cite the line,
   the rule it violates, the proposed fix.
4. **Apply the fixes** using your file edit tools. Edit ONLY the target file
   (`$TARGET_FILE`). Do not edit fabricators, page objects, support files,
   or any other path — those are out of scope for THIS iteration. If the
   file needs broader changes (e.g. a page object class that should also
   change), note it in `<iter_dir>/rationale.md` under a "Follow-ups"
   section, but do not change those files now.
5. **Write `<iter_dir>/summary.txt`** with a one-line description of the
   change (≤120 chars). Examples:
   - `consolidate 3 trivial expectation blocks into one; rename single-letter |v| to |vote|`
   - `flatten 3-level nesting to 2 levels; rewrite negative assertion to reference the post object`
   - `no changes needed`
6. **Write `<iter_dir>/rationale.md`** with these sections:
   - **Audit** — bullet list of every deviation found (cite line + rule).
   - **Changes** — what you actually changed and why each preserves
     behaviour. For consolidations, state explicitly which assertions
     remain and which examples were merged into which.
   - **Skipped** — deviations you noticed but deliberately didn't fix
     (e.g. requires editing out-of-scope files), with rationale.
   - **Risk** — anything you're uncertain about — e.g. a consolidated
     example whose assertion order may matter, a renamed variable used
     elsewhere in the file you should double-check.

## Hard rules

1. **Edit only `$TARGET_FILE`.** Out-of-scope edits will be reverted before
   the file's tests run.
2. **The behavioural contract must hold.** Every assertion that exists
   before your edits must still exist after, in some form. Consolidating
   two `it` blocks into one means BOTH original assertions live in the
   merged block. You can rename, regroup, and reorder, but you cannot
   delete an assertion without replacing it with an equivalent.
3. **Forbidden constructs** (auto-rejected by grep):
   - New `xit`, `xspecify`, `xfeature`, `xdescribe`, `xcontext`
   - `, skip:` / `, :skip` / `, pending:` metadata
   - Bare `skip` / `pending` calls inside example bodies
   - `fit`, `fdescribe`, `fcontext`
4. **Coverage**: the static `it`/`scenario`/`specify`/`example`/`feature`
   block count may decrease (consolidation is encouraged by the
   guidelines) but not by more than 50%. Sweeping deletion = reject.
5. **The file must still pass `bin/rspec $TARGET_FILE`** after your edits.
   The surrounding driver runs this verification automatically.
6. **No comments narrating the change** ("# moved this", "# consolidated
   from 3 examples"). Tests are documentation; commit-message + rationale
   carry the change story. Code comments stay if they explain non-obvious
   *behaviour*, not history.
7. **If the file is already compliant**, write `no changes needed` to
   `summary.txt`, do not edit anything, and explain in `rationale.md`
   what you checked.

## What you should NOT do

- Don't try to "improve performance" — that's a separate loop. Stick to
  guideline compliance.
- Don't introduce new dependencies (gems, helpers, support modules).
- Don't refactor production code under `app/`, `lib/`, etc. The file's
  fixture must still match production behaviour exactly.
- Don't change the file's name, location, or the top-level `describe`
  subject. Renaming is its own change.
- Don't rewrite the whole file when surgical edits do.

## Output protocol summary

Every iteration MUST produce:

- `<iter_dir>/summary.txt` — one-liner.
- `<iter_dir>/rationale.md` — structured (Audit / Changes / Skipped / Risk).
- Edits to `$TARGET_FILE` only (or no edits if `no changes needed`).

Do not commit, push, run rspec for verification, or interact with git/gh
— the driver handles all of that.
