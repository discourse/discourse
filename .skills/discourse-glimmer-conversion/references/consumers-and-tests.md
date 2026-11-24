# Consumers and tests

## Discovery

Use `scripts/analyze.sh` as an index. Verify imports, angle-bracket and curly invocations,
subclasses, and `component:<name>` registry or `modifyClass` lookups. Check aliases,
component maps, and `curryComponent` when an import leads to an indirect caller. Scan
bundled plugins and the available external checkouts. Themes can override a core resolver
name with a non-colocated `templates/components/*.hbs` backed by a classic class
(`instance-initializers/component-templates.js`, `8f52b81efa7`). Keep the module path and
resolver name stable.

Inspect functions that receive the component instance. For example,
`getTopicFooterButtons(this)` gives plugin callbacks the component as their receiver and
implements legacy dependent keys with `context.get()`. This needs a plugin API change
before the conversion. A plain arg callback can also depend on its receiver.
`this.args.done()` supplies the args object where `this.done()` supplied the component.
Preserve the receiver when it is part of the contract. In #43534 only the
`WatchedWordUploader` test used it, so the test could assert the actual callback contract.

### Extension changes

On a `.gjs` to `.gts` rename, extensionless imports and string lookups keep resolving.
Update explicit-extension imports. The analyzer lists candidates, but lint and type
checking may miss a stale relative path. If `bin/dev` reports `UNLOADABLE_DEPENDENCY` for
the old path after you update the imports, remove that module's stale generated
declarations under `frontend/discourse-types/declarations/` and restart `bin/dev`.

## What each call site needs

- Change classic `@classNames` or `@class` to `class=`, and `@elementId` or `@id` to
  `id=`. Handle `@tagName` through the
  [wrapper recipe](feature-mapping.md#wrapper-element).
- Preserve the values callers pass. If migrating from a truthiness check to a strict
  boolean check, update a string such as `@triggerAppEvent="true"` to
  `@triggerAppEvent={{true}}` (`d6d3fc86294`). See
  [action helper replacements](data-flow.md#6-action-and-mut-leftovers-at-call-sites)
  for string action names.
- Check writes through args and give callers any
  [required callbacks](data-flow.md#3-choose-the-redesign). Keep args that may be supplied
  by external consumers even if in-tree callers pass nothing.
- Update an in-repo `api.modifyClass` patch for Glimmer args and lifecycle, or fold it
  into the component if appropriate. Before replacing a patch's `classNameBindings`,
  check downstream CSS and selectors. For `SearchResultEntry`, a private plugin relied
  on `.ai-result`. #44615 preserved the class through a value transformer.

### Plugin outlets

A Glimmer connector receives individual outlet args as `@topic` or `this.args.topic`.
The entire hash remains available as `@outletArgs`. In the component rendering
`<PluginOutlet>`, keep `@outletArgs` and update its contents. For example,
`@outletArgs={{lazyHash topic=this.topic}}` becomes
`@outletArgs={{lazyHash topic=@topic}}` when topic is an arg (`323013d9c79`).
If children rerender unexpectedly, inspect fresh object identities
(`707a91243c3` → `f8d61a341e0` → `3867c879ab8`).
Give classic connectors that had a wrapper the same explicit wrapper as any other
component.

### External consumers

For each breaking external use, report the file and the required edit. An inherited class
that only reads old base properties may still work if the base exposes same-named getters.
`DDateTimeInput` used this to preserve reads in discourse-custom-wizard. A classic
subclass that calls `this.set()` or relies on classic hooks needs a coordinated change.
A template-only export makes an external `extends` fail at import time and leaves
`modifyClass` without a class to patch. If an empty backing class is explicitly required
for compatibility, scope the `ember/no-empty-glimmer-component-classes` exception to that
class and name the consumer.

## Tests

### Integration tests for the component

Follow the [JS test skill](../../discourse-writing-js-tests/SKILL.md).
When rewriting a legacy rendering test, use `.gjs` with an inline template and a real
component import. Existing passing `.gjs` tests can keep `this.set()` on the test context.
For new coverage of a changing arg, use a `tracked(v)` box and `await rerender()`:

```gjs
test("updates when the arg changes", async function (assert) {
  const value = tracked("a");

  await render(<template><FooBar @value={{value.value}} /></template>);
  assert.dom(".foo-bar").hasText("a", "renders the initial value");

  value.value = "b";
  await rerender();
  assert.dom(".foo-bar").hasText("b", "re-renders when the arg changes");
});
```

Objects the component mutates through an arg must be reactive and the test must assert
the write reached the caller (adapted from `c96dce29348`):

```gjs
const status = trackedObject({ emoji: "tooth", description: "off to dentist" });
await render(<template><UserStatusPicker @status={{status}} /></template>);
await click(".btn-emoji");
await click(".emoji-picker .emoji[title='mega']");
assert.strictEqual(status.emoji, "mega", "writes the picked emoji to the status object");
```

### Traps when writing them

- One test per redesigned two-way binding (callback fires, arg is not mutated). Render the
  converted component directly with a recording callback. A test through the real parent
  can miss callback removal when a [classic child writes through](data-flow.md#5-built-in-inputs-inside-the-converted-component).
  The theme editor's in-place enum test still passed with `@onChange` removed. Make the
  direct test fail when you remove the callback.
- A test for a `get()` read must change *only* the untracked field. If the same change also
  flips a tracked value the template reads around the getter (an `{{#if}}` block), the block
  renders fresh and the test passes without the fix. `ComposerActionTitle` reads
  `Composer#action` (plain) through `get()`; switching REPLY → EDIT also creates the reply
  target that wraps the button, so the test switches EDIT → EDIT_SHARED_DRAFT, where the
  target stays and only the `=== EDIT` check flips. Check the field is really untracked
  first: `Post#can_edit` is a tracked accessor and needed no `get()`.
- A mutation that removes `@tracked` from a field written through `(mut this.x)` still
  passes: `mut` writes with `set()`, which notifies the template on any field. Only plain
  assignments (`this.x = v`) need the decorator to update the DOM.
- A test category takes its subcategories from the site fixtures by id:
  `Category#subcategories` reads `site.categoriesByParentId`, so
  `store.createRecord("category", { id: 2, ... })` got fixture category 2's children, its
  `isHidden` was false, and a muted-list test failed on the classic file as well. Use
  childless fixture ids (3, 4); an id the site does not know breaks the category helpers.
- `settled()` does not wait for an Uppy upload to complete. Hold the upload request in
  pretender to assert the in-flight state, then `waitUntil` the finished state.
- `discourseLater` runs as soon as the test settles, so a delayed side effect fires inside
  the `await click(...)` that scheduled it. Test a teardown path (`willDestroy`) on its own,
  starting from the state the delay would have produced.

### Finding the test that actually exercises the component

Selector matches can miss the page that renders the component, especially with generic
classes such as `.field`. Check tests named for the caller's page too.
`AdminEditableField`'s save path was covered by `acceptance/admin-user-index-test.js`,
named for `admin/templates/admin-user/index.gjs`. Verify the behavior each test covers
and run relevant files by path. A spaced `--filter` may match zero tests when the module
uses a PascalCase component name.

### Running tests against `bin/dev`

- **A dozen files in one `bin/qunit` run** has aborted at a random test with
  `Browser timeout exceeded: 30s`, on `origin/main` as well, while the named test passes
  alone. When that happens, loop over the files with one invocation each and collect the
  `# pass`/`# fail` lines.
- **A newly created test file** is not picked up by a running `bin/dev` (rolldown
  re-evaluates its inputs but not the test-entrypoint glob), so `bin/qunit` reports
  `No tests matched with the filter`. Restart `bin/dev` and wait for the file to appear in
  `frontend/discourse/dist/assets/js/` before believing the run. Edits to existing files are
  picked up normally.
- **After editing a file for a mutation run**, wait for `[ember] Rebuild complete ... <path>`
  in the `bin/dev` log, both after the mutation and after restoring it. A fixed `sleep` is not
  enough for a widely imported module (`d-user-info` rebuilt 89 files), and the run then
  tests the old bundle.
- **After copying other versions over your files and back** (to compare against the
  classic file), the watcher can keep serving a stale module (`bulk-user-suspend-confirmation`
  stayed at `origin/main`'s version for an hour; `touch` did not help). Restart `bin/dev`
  before system specs, which load the same `frontend/discourse/dist`.

### Components that mount a third-party editor

`AceEditor` registers a test waiter in its `setContent` modifier and ends it on ace's next
`afterRender`, which never comes when the editor has no size. A component that renders an
`AceEditor` without forwarding `...attributes` to it therefore hangs for the full 60s test
timeout with `hasPendingWaiters` and a pending `ace-editor` waiter. Give the editor a size
from the test instead: append a `<style>` element to `document.head` in `beforeEach`
(`.ace_editor { width: 300px; height: 200px; }`) and remove it in `afterEach`; a `<style>`
tag inside `<template>` is rejected by `ember/template-no-forbidden-elements`.

### Acceptance and system tests

Run the acceptance and system tests that exercise the changed behavior. Update selectors
when a required markup change affects them.

Timing-dependent replacements (IntersectionObserver, ResizeObserver, `matchMedia`) do not
fire deterministically in tests; assert on state you can drive (`TrackedMediaQuery`
value, a tracked flag) instead of waiting, and expose a test toggle only as a last resort.
