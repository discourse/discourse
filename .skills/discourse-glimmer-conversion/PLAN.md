# Glimmer conversion plan

Where the campaign to retire classic components in core and bundled plugins stands, how
targets are picked and batched, and what the first ten batches taught. SKILL.md is the
per-component procedure; this is the layer above it. The PR log is [PROGRESS.md](PROGRESS.md);
the research behind the skill is [DESIGN.md](DESIGN.md).

## Status (2026-09-24)

- 176 classic components on `main`, 64 of them converted or deleted in open PRs
  (#43390, #43521–#43543). 12 single-component PRs are merged.
- `scripts/rank-targets.py` ranks 96 remaining candidates and lists 4 as blocked (below).
  `select-kit/` and the infrastructure users of `@ember/component` are out of scope.
- The easy tier is used up. The top of the ranking is now data-flow work, so the batching
  approach changes for the next phase (see "Next").

## Tooling

- `scripts/rank-targets.py`: ranks `origin/main`'s classic components by risk. It reads git
  directly, so it works from any checkout state. It leaves out files in open
  `glimmer-conversion` PRs and prints unreachable components separately. It takes about
  2.5 minutes. Run `git fetch origin main` first.
- `scripts/analyze.sh <file>`: the per-component pre-flight (SKILL.md Step 1).
- `PROGRESS.md`: PR log, updated with every PR (SKILL.md Step 10).

## Picking targets

The risk score counts what makes a conversion expensive or easy to get wrong: lifecycle
hooks and observers (×3), `this.element`/jQuery, mixins (×5), subclasses (×6), class
bindings, element event handlers, `@computed`s, two-way writes including template-side
`(mut this.x)` (×4), external consumers (×4), an implicit wrapper `<div>`, extra call sites,
and size. Lowest first. The score only orders the work. Each pick still gets the full
pre-flight.

Rules the ranking can't apply for you:

1. **No call sites means dead, not easy.** The first "easiest" targets were all
   unreferenced. Confirm against the external checkouts with anchored patterns, then delete
   in a separate PR (#43390, #43531). The script prints these as `DEAD?`.
2. **`fields:` in the output is a warning, not trivia.** A class field that callers also
   pass is at best an override (`this.args.x ?? default`) and at worst a flag shared with
   the caller. `AdminEditableField`'s `editing` was the second kind and shipped broken
   (see Lessons).
3. **`2way:` means a data-flow decision.** Leave these out of mixed batches. An arg
   forwarded untouched into a classic child that sets it (`DEditor`, `ValueList`,
   select-kit without `@onChange`) keeps working through Glimmer, but only because the write
   goes through the reference, hidden. Give the child a callback anyway (data-flow §5).
4. **Blocked, each needing its own PR or a decision** (the `BLOCKED` list in the script):
   `anonymous-topic-footer-buttons` (passes `this` into a plugin API that calls
   `.get()`) and `discourse-root` (converted once and reverted). `reviewable-field-editor`
   was listed for its `DEditor` write. The write-through finding above makes it an ordinary
   callback conversion, as long as `DEditor` takes an `@onChange`.

## Batching

- **Ten components per PR**, each converted one at a time with its own pre-flight, plan, and
  verification. One commit, one draft PR, label `glimmer-conversion`, branch
  `0-glimmer-batch-<n>` off `origin/main`.
- Batch members must be independent: no two may change the same call site. Sharing an
  untouched call site is fine.
- Drop a member rather than rush it. If it needs a data-flow decision, a plugin-API change,
  or a test rewrite, it goes in its own PR and the next candidate takes its place.
- Commit and PR share a title and body: the fixed opening sentence, class names grouped
  by origin, then one short sentence per interface change or fixed bug, saying what
  changed. Skip the mechanics and anything that was kept (a wrapper, a file rename).
- Bugs found along the way are fixed when the fix is the same size as or smaller than
  preserving them (the `textParams` interpolation, the empty `as_sitesearch` input), and
  flagged otherwise.

## Verification that actually catches things

- Run each test file **by path**. Module names are PascalCase, so
  `--filter "watched word"` silently matches nothing (#43534 shipped a broken test).
- Run the acceptance test for **each call site's page**, not only tests named after the
  component. `analyze.sh` now lists them ("tests named after a call site's page");
  `admin-user-index-test.js` would have caught #43541's regression.
- Add an integration test when a component has none and changes behavior, redesigns a
  binding, or has a reactivity risk. Mutation-test it: revert the fix, watch it fail.
- A running `bin/dev` does not pick up **new** test files; restart it (see
  `references/consumers-and-tests.md`). After deleting or renaming frontend files, delete
  the matching generated `.d.ts` or the build fails with `UNLOADABLE_DEPENDENCY`.

## Lessons from the first ten batches

Each has a full entry in `references/`; these are the ones that cost a CI round or a revert.

- **Shared flags behind class fields** (#43541, `AdminEditableField`): the component opened
  edit mode through a two-way `@editing`, and the controller closed it after saving. The
  fix is caller-owned state plus a `@toggleEditing` callback.
- **The callback receiver changes** (#43534, `WatchedWordUploader`): `this.done()` →
  `this.args.done()` calls the callback with `this.args` as its receiver. Production was
  safe (`@action`-bound) but a test relied on it.
- **Untracked model fields** (`CategoriesBoxesTopic`, `EmailStylesEditor`): in a native
  getter, `topic.pinned` or `styles.css` does not track. Read with `get()`. The old tests
  could not tell, so add a reactivity test.
- **Implicit wrappers carry CSS meaning** (`ReviewableField`): the anonymous `<div>` kept
  `:not(:last-child)` from matching. Keep the wrapper.
- **`@discourseComputed` → `@computed` dropped arguments** (`DiscourseLinkedText`): a
  dependency key the getter never reads is often a regression from that sweep, not dead
  weight.
- **Connectors take outlet args as plain args.** Use `@topic`, not `@outletArgs.topic`,
  whenever a connector is touched.

## Next

1. **The site-settings list family** (`url-list`, `host-list`, `simple-list`,
   `tag-group-list`, `named-list`, `enum`, `tag-list`, `group-list`, `value-list`) is
   converted in #44570. The contract: each component reads the stored string
   from `@value`, converts it for its control, and reports the new stored string through
   `@changeValueCallback`. That callback is the only write path, already passed by
   `site-setting.gjs` and its four `trackChanges = false` subclasses. Delimiters differ:
   `url_list` and `value_list` are newline-joined, the rest pipe-joined. Only `url-list` passed its arg into a
   writing child; the other seven wrote their own `value`.
2. **Resume ten-per-PR batches** from what's left once the family is out of the way:
   components with a hook or observer but no two-way args (`signup-cta`,
   `styleguide-section`, `flag-selection`).
3. **Hierarchies** (`edit-category-panel`'s `buildCategoryPanel` factory and its panels):
   one PR per hierarchy, per SKILL.md Step 0.
4. **Blocked items** last, each with its own design: first the `getTopicFooterButtons`
   receiver contract, then `discourse-root` only with a clear reason for the earlier revert.
5. **External consumers** flagged in PR reports (for example the third-party plugin that
   passes `@editing` to `AdminEditableField`) need follow-ups outside this repo once the
   PRs land.
