# Glimmer conversion plan

Where the campaign to retire classic components in core and bundled plugins stands and how
targets are picked. SKILL.md is the per-component procedure and its Step 10 the batching
rules; this is the layer above it. The PR log is [PROGRESS.md](PROGRESS.md); the research
behind the skill is [DESIGN.md](DESIGN.md).

## Status

`scripts/rank-targets.py` prints the live totals (classic components left, in flight,
ranked, blocked, unreachable) in its first two lines, and PROGRESS.md lists every PR. The
easy tier is used up: the top of the ranking is data-flow work, blocked items, and ui-kit
components that come out as `.gts`.

## Tooling

- `scripts/rank-targets.py`: ranks `origin/main`'s classic components by risk. It reads git
  directly, so it works from any checkout state. It leaves out files in open
  `glimmer-conversion` PRs and prints unreachable components separately; `--list` prints
  the inventory only. It takes a few seconds. Run `git fetch origin main` first.
- `scripts/analyze.sh <file>`: the per-component pre-flight (SKILL.md Step 1).
- `scripts/self-args.py`: template `@name` reads that shadow a member (SKILL.md Step 8).
- `scripts/refresh-progress.py`: the merged/approved marks in PROGRESS.md (SKILL.md Step 10).
- `scripts/component-history.py`: an HTML chart of classic vs Glimmer counts over time.
- `scripts/common.py`: what the Python scripts share (git and gh calls, module resolution
  from the tsconfig `paths`, the `.gts` rule).

## Picking targets

The risk score counts what makes a conversion expensive or easy to get wrong: lifecycle
hooks and observers (×3), `this.element`/jQuery, mixins (×5), subclasses (×6), class
bindings, element event handlers, `@computed`s, two-way writes including template-side
`(mut this.x)` (×4), external consumers (×4), an implicit wrapper `<div>`, extra call sites,
and size. Lowest first. The score only orders the work. Each pick still gets the full
pre-flight.

Rules the ranking can't apply for you:

1. **`DEAD?` means delete, not convert** (SKILL.md Step 1), in a separate PR (#43390,
   #43531). The first "easiest" targets were all unreferenced.
2. **`fields:` in the output is a warning, not trivia.** A class field that callers also
   pass is at best an override (`this.args.x ?? default`) and at worst a flag shared with
   the caller. `AdminEditableField`'s `editing` was the second kind and shipped broken
   (#43541; see the pitfalls reference).
3. **`2way:` means a data-flow decision.** Leave these out of mixed batches. An arg
   forwarded untouched into a classic child that sets it (`DEditor`, `ValueList`,
   select-kit without `@onChange`) keeps working through Glimmer, but only because the write
   goes through the reference, hidden. Give the child a callback anyway (data-flow §5).
4. **`ts` means the result is `.gts`** (ui-kit, or a mostly TypeScript directory or family).
   It adds a `Signature`, TSDoc, and for ui-kit a type test, so count it as extra work when
   filling a batch (SKILL.md Step 1).
5. **`BLOCKED` entries need their own PR or a decision first.** The script prints each one
   with its reason; remove an entry from `BLOCKED` once its blocker is gone.

## Next

1. **The ui-kit components flagged `ts`** come out as `.gts` with a `Signature`, TSDoc and a
   type test. Batch them together so the TypeScript review happens once.
2. **Hierarchies** (`edit-category-panel`'s `buildCategoryPanel` factory and its panels):
   one PR per hierarchy, per SKILL.md Step 0.
3. **Blocked items** last, each with its own design: first the `getTopicFooterButtons`
   receiver contract, then `discourse-root` only with a clear reason for the earlier revert.
4. **External consumers** flagged in PR reports (for example the third-party plugin that
   passes `@editing` to `AdminEditableField`) need follow-ups outside this repo once the
   PRs land.
