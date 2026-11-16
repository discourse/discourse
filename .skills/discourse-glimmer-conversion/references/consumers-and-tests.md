# Consumers and tests

How to find everything that depends on a component, what to do with each category, and
how to convert its tests. `scripts/analyze.sh` runs the greps below; this file explains
what each result means and what you owe it.

## Consumer categories

| Category | Where | Action |
|---|---|---|
| Angle-bracket invocations | core, bundled plugins, tests | edit in the same change |
| Import of the class (composition, `<this.dynamic>` maps, `curryComponent`) | same | edit |
| Subclasses (`extends Foo`, `Foo.extend(`) | core, bundled plugins | convert in the same change or stop (Step 0) |
| String lookups (`{{component "foo"}}`, `component:foo` in a resolver map, `owner.lookup`) | same | keep the file path; edit the invocation if it passed `tagName`/`classNames` |
| `api.modifyClass("component:foo")` in a bundled plugin | `plugins/*/assets/javascripts` | keep path and name; rewrite the patch against `this.args` and modifiers, or fold it into the component |
| `api.modifyClass("component:foo")` in an external checkout | `~/discourse/all-the/…` | keep path and name; flag with what breaks |
| Plugin outlet connectors passing args into it | plugins, themes | edit bundled; flag external |
| External plugins and themes (`~/discourse/all-the/…`) | `all-the-plugins/{official,third-party}`, `all-the-themes/{official,third-party}`, `all-the-custom-{plugins,themes}` | never edit; list the file and the exact edit |
| Tests (`-test.gjs`, system specs by CSS selector) | `frontend/discourse/tests`, `plugins/*/test/javascripts`, `spec/system`, `plugins/*/spec/system` | convert or update |

## Discovery

The script derives the import path (`discourse/components/foo`,
`discourse/admin/components/foo`, `discourse/plugins/<plugin>/discourse/components/foo`,
`discourse/plugins/<plugin>/admin/components/foo`), the resolver name (`foo`, or `foo/bar`
for nested), and the class name from the file. For a component in another repo it scans
that repo and the core checkout (`CORE_DIR` overrides which one). Use its output rather
than hand-written greps: its resolver patterns are anchored, its imports allow the
extension relative imports carry, and it covers every external checkout.


Also grep for the component's CSS classes in `spec/system` and
`frontend/discourse/tests/acceptance`: system specs find elements by class, and a changed
wrapper or a `<DButton>` replacing an `<a>` changes what those selectors match.

## What each call site needs

Read every invocation and record, per arg:

- **Passed and read only**: unchanged. `@foo={{this.x}}` keeps working.
- **Passed and written by the child**: the two-way binding. Decide per the data-flow
  reference; the call site gains a callback (`@onChange={{this.action}}` or
  `{{fn (mut this.x)}}`) and the child stops writing.
- **Passed as `@tagName`, `@classNames`, `@class`, `@id`, `@elementId`**: classic wrapper
  configuration. Becomes a plain attribute on the invocation (`class=`, `id=`), or a
  changed wrapper tag in the component when only one value was ever passed.
- **Passed as a string that should be a boolean/number** (`@foo="true"`): keep the classic
  string semantics unless the component compares strictly; then `{{true}}`.
- **Passed as a string action name** (`@action="save"`): must become a function.
- **Not passed anywhere but read by the component**: dead arg; keep the read (it may be a
  theme's arg) unless it is clearly internal.
- **Passed positionally or via `{{foo-bar x}}` curly invocation**: convert to named args
  and angle brackets.

Every call site edit is verified by opening the page or running the test that renders it.

## External consumers: the report entry

For each hit outside core and bundled plugins, the report lists:

```
~/discourse/all-the/all-the-plugins/official/<plugin>/assets/javascripts/discourse/initializers/x.js:12
  modifyClass("component:composer-body") overrides `didInsertElement` and reads `this.composer`.
  After conversion: hook no longer exists; read `this.args.composer`; move DOM setup to a modifier.
```

The user decides whether the conversion waits for those repos or ships with a
deprecation. Do not soften the wording; a missed external consumer is a production break
in someone else's site.

## Tests

### Integration tests for the component

Structure per the `discourse-writing-js-tests` skill:
`setupRenderingTest(hooks)` from `discourse/tests/helpers/component-test`, `render` and
`rerender` from `@ember/test-helpers`, an inline `<template>` with a real import, `assert.dom`.

Outer state the test mutates after rendering goes in a standalone `tracked(v)` box from
`@glimmer/tracking`, not a local class with a `@tracked` field; this replaces
`this.set(...)` on the classic test context:

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

Why `rerender()` and not `settled()` after a tracked change, and the box's semantics
(`Object.is` dedupe, `tracked(undefined)` for an empty box), are in
`discourse-writing-js-tests`. `this.set("x", ...)` on the test context still works (the
template is lexically bound to the test function's `this`), which is why passing
`this.set` tests are left alone.

Objects the component mutates through an arg must be reactive and the test must assert
the write reached the caller (adapted from `c96dce29348`, which used `new TrackedObject`
from the now-retired compat package):

```gjs
const status = trackedObject({ emoji: "tooth", description: "off to dentist" });
await render(<template><UserStatusPicker @status={{status}} /></template>);
await click(".btn-emoji");
await click(".emoji-picker .emoji[title='mega']");
assert.strictEqual(status.emoji, "mega", "writes the picked emoji to the status object");
```

Callbacks added for a redesigned two-way binding get a test that passes a recording
function and asserts it was called with the new value.

### Traps when writing them

- One test per redesigned two-way binding (callback fires, arg is not mutated). Render the
  converted component directly with a recording callback. A test through the real parent
  cannot tell the callback from a classic child writing through a forwarded `@value` (see
  data-flow §5): the in-place enum test on the theme editor still passed with `@onChange`
  removed. Mutation-test against the direct test.
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
- `settled()` does not wait for an Uppy upload to complete. Hold the upload request in
  pretender to assert the in-flight state, then `waitUntil` the finished state.
- `discourseLater` runs as soon as the test settles, so a delayed side effect fires inside
  the `await click(...)` that scheduled it. Test a teardown path (`willDestroy`) on its own,
  starting from the state the delay would have produced.

### Finding the test that actually exercises the component

Selector greps go blind when the component's classes are generic (`.field`, `.value`,
`.name`): the script prints forty unit tests that happen to mention them and the one test
that renders the component is not among them. The script's "tests named after a call site's
page" section closes that gap — it matches test *filenames* against each call site's path
(`admin/templates/admin-user/index.gjs` → `acceptance/admin-user-index-test.js`). Run those,
not just the ones matching the component name; `AdminEditableField` shipped broken because
`admin-user-index-test.js` was never run.

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

Run every acceptance test whose module or selectors reference the component's classes,
and the system specs the script lists. When markup changed unavoidably, update selectors
in the same change and say so in the report.

Timing-dependent replacements (IntersectionObserver, ResizeObserver, `matchMedia`) do not
fire deterministically in tests; assert on state you can drive (`TrackedMediaQuery`
value, a tracked flag) instead of waiting, and expose a test toggle only as a last resort.
