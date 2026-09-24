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

## Discovery greps

The script derives the import path (`discourse/components/foo`,
`discourse/admin/components/foo`, `discourse/plugins/<plugin>/discourse/components/foo`,
`discourse/plugins/<plugin>/admin/components/foo`), the resolver name (`foo`, or `foo/bar`
for nested), and the class name from the file. For a component in another repo it scans
that repo and the core checkout (`CORE_DIR` overrides which one). Manual equivalents:

```bash
# invocations and imports in core + bundled plugins
grep -rnE '<FooBar\b|from "discourse/components/foo-bar"' frontend plugins --include='*.gjs' --include='*.gts' --include='*.js' --include='*.ts' | grep -v node_modules
# string lookups
grep -rnE '"foo-bar"|component:foo-bar' frontend plugins --include='*.gjs' --include='*.js' | grep -v node_modules
# subclasses
grep -rnE 'extends FooBar\b|FooBar\.extend\(' frontend plugins | grep -v node_modules
# modifyClass
grep -rnE 'modifyClass\(\s*["'"'"'`]component:foo-bar' frontend plugins ~/discourse/all-the/all-the-plugins ~/discourse/all-the/all-the-themes ~/discourse/all-the/all-the-custom-plugins ~/discourse/all-the/all-the-custom-themes --exclude-dir=node_modules --exclude-dir=.git
# external imports
grep -rlF '"discourse/components/foo-bar"' ~/discourse/all-the/all-the-plugins ~/discourse/all-the/all-the-themes --exclude-dir=node_modules --exclude-dir=.git
```

In zsh, pass multiple directories through an array (`dirs=(a b c); grep ... "${dirs[@]}"`),
not an unquoted scalar; zsh does not word-split scalars, so the grep silently searches a
path that does not exist and returns nothing.

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
`settled` from `@ember/test-helpers`, an inline `<template>` with a real import, `assert.dom`.

Outer state the test mutates after rendering goes in a local tracked class; this replaces
`this.set(...)` on the classic test context:

```gjs
test("updates when the arg changes", async function (assert) {
  const state = new (class {
    @tracked value = "a";
  })();

  await render(<template><FooBar @value={{state.value}} /></template>);
  assert.dom(".foo-bar").hasText("a", "renders the initial value");

  state.value = "b";
  await settled();
  assert.dom(".foo-bar").hasText("b", "re-renders when the arg changes");
});
```

`this.set("x", ...)` on the test context with `{{this.x}}` inside the `<template>` still
works (the template is lexically bound to the test function's `this`); prefer the tracked
class for new tests and leave existing `this.set` tests alone unless they break. Only a
test that still uses an `hbs` string or lives in a `.js` file gets converted to `.gjs`
with an inline `<template>` and a real import. A component with no integration test gets
one covering the wrapper, each redesigned binding, and each lifecycle replacement, unless
the report names the acceptance tests that already cover it.

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

Defaults the classic hook created (`if (!this.status) this.set("status", {})`) either come
back as a getter default or are passed by the test explicitly; do not let the test paper
over a dropped default the callers relied on.

### What to add

- One test per redesigned two-way binding (callback fires, arg is not mutated).
- One test per arg that `didReceiveAttrs`/`didUpdateAttrs` used to react to (change the
  arg, `settled()`, assert the DOM or state followed).
- One test per class-field default that callers override with an arg.

### Finding the test that actually exercises the component

Selector greps go blind when the component's classes are generic (`.field`, `.value`,
`.name`): the script prints forty unit tests that happen to mention them and the one test
that renders the component is not among them. The script's "tests named after a call site's
page" section closes that gap — it matches test *filenames* against each call site's path
(`admin/templates/admin-user/index.gjs` → `acceptance/admin-user-index-test.js`). Run those,
not just the ones matching the component name; `AdminEditableField` shipped broken because
`admin-user-index-test.js` was never run.

### Running a test file you just created

A running `bin/dev` does not pick up a **newly created** test file: rolldown re-evaluates
its inputs but not the test-entrypoint glob, so `bin/qunit path/to/new-test.gjs` fails with
`No tests matched with the filter: ...` while `frontend/discourse/dist` keeps rebuilding
happily. Restart `bin/dev` and wait for the new file to appear in the bundle
(`grep -rl <basename> frontend/discourse/dist/assets/js/`) before believing the run. Editing
an existing test file is picked up normally.

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
