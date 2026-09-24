---
name: discourse-glimmer-conversion
description: Convert a classic Ember component (`import Component from "@ember/component"`, `@ember-decorators/component`, `didInsertElement`, `@computed`, `@observes`, `this.set`) into a Glimmer component (`@glimmer/component`) in Discourse core, bundled plugins, external plugins, or themes. Use when asked to convert, modernize, or glimmerize a component, or to remove an `eslint-disable ember/no-classic-components` banner. Covers scope triage, the pre-flight plan, args vs own state, wrapper element reconstruction, lifecycle-to-modifier mapping, two-way binding redesign, call-site and external-consumer updates, tests, verification, and the report.
---

# Converting classic components to Glimmer

Classic components conflate four things Glimmer separates: args and own state (both
`this.foo`), an implicit wrapper element configured by class decorators, lifecycle hooks
tied to DOM presence, and two-way bindings that let a child write into its parent. A
conversion untangles all four while changing as little else as possible. Work through the
steps in order; do not start editing before Step 1 has produced a plan.

References (read the one matching the step; they contain the before/after snippets):

- [references/feature-mapping.md](references/feature-mapping.md): every classic feature and
  its replacement, with snippets from this repo.
- [references/data-flow.md](references/data-flow.md): finding and redesigning two-way
  bindings, updating call sites, built-in inputs, select-kit, outlets.
- [references/consumers-and-tests.md](references/consumers-and-tests.md): discovery for
  core, bundled plugins, external checkouts, `modifyClass`, subclasses, and the test patterns.
- [references/pitfalls.md](references/pitfalls.md): regressions past conversions caused and
  the commits that show them. Read at Step 8, after the commands and before the report.

Companion skills: `discourse-frontend-conventions` (member order, private symbols,
attribute/argument/modifier ordering on every element you touch; apply only to lines you
add or change), `discourse-writing-js-tests`, `discourse-pr` for the commit subject.

Imports you will reach for: `modifier` from `ember-modifier`; `tracked`, `cached` from
`@glimmer/tracking`; `on` from `@ember/modifier`; `fn`, `array` from `@ember/helper`;
`dConcatClass` from `discourse/ui-kit/helpers/d-concat-class`; `dElement` from
`discourse/ui-kit/helpers/d-element`; `resettableTracked` from `discourse/lib/tracked-tools`;
`helperFn` from `discourse/helpers/helper-fn`; `bind`, `afterRender` from
`discourse/lib/decorators`; `trackedArray`, `trackedObject` from `@ember/reactive/collections`;
`untrack` from `@glimmer/validator`; `or`, `and`, `not` from `discourse/truth-helpers`;
`getOwner` from `@ember/owner`; `get` from `@ember/object`.

## Golden rules

1. **Minimal viable change.** Same file path, same name, same arg names, same yields, same
   DOM, same CSS classes and ids, same behavior. No drive-by refactors, no jQuery removal,
   no ui-kit swaps, no renames, unless it falls out of the conversion at zero extra cost.
   A reviewer should be able to read the diff as "classic → Glimmer" and nothing else.
2. **Tracked state and native getters only.** No `@computed`, no computed macros, no
   `@observes`, no `this.set`/`this.get` on own state, no `actions: {}` hash.
3. **Lifecycle goes to Glimmer-compatible mechanisms.** `constructor`, `willDestroy`,
   `modifier()` from `ember-modifier`, `helperFn`, `@resettableTracked`, `@cached`, keyed
   `{{#each}}`. Do not add `@ember/render-modifiers` (`didInsert`/`didUpdate`/`willDestroy`);
   lint policy calls them an anti-pattern. Existing uses in files you did not convert stay.
4. **The wrapper element is part of the contract.** Reproduce it in the template with
   `...attributes` unless the component was `@tagName("")`.
5. **Every consumer is found.** Core, bundled plugins, tests, and plugin outlets are
   updated in the same change; external plugin/theme checkouts are never edited, and each
   hit is listed in the report with the exact edit. Two-way-bound args are redesigned case
   by case; the callback shape is chosen from the caller's needs, never mechanically.
6. **Pre-existing bugs**: fix only when the fix is the same amount of code or less than
   preserving the bug. Otherwise preserve the behavior and flag it in the report. Either
   way, list it.
7. **Reactivity chains are converted whole.** A base class and its subclasses go together.
   A classic consumer whose dependent-key chain crosses a native getter you introduce (a
   model, a service, a yielded object) stops updating; convert that consumer too or bridge
   the getter with `@dependentKeyCompat`. Prefer converting leaves that feed no classic
   consumer first.

## Step 0: scope triage

One component per change, plus its in-tree subclasses when it is a base class, plus a
classic consumer when golden rule 7 requires converting it together, plus the call-site
edits. When asked for several (a directory, a plugin), convert them one commit-sized
change at a time, leaves first, and report per component.

Stop and flag, or widen the scope, when:

- the file is under `select-kit/`: select-kit is a framework with a dozen external
  subclasses; it needs its own migration, not this skill. Stop.
- the component is a **base class** (`export default class X extends Component` that other
  components `extends`): a scope decision, not a stop. Convert the whole hierarchy in one
  change or none of it; a Glimmer base under a classic subclass does not work.
- the file is one of the infrastructure users of `@ember/component` (`lib/ember-events.js`,
  `lib/implicit-injections.js`, `instance-initializers/component-templates.js`,
  `ui-kit/helpers/d-element.gts`): not components, leave them.
- the file only imports `{ Input }`, `{ Textarea }`, or `{ setComponentTemplate }` from
  `@ember/component`: not a classic component. Two-way `<Input @value>` inside a Glimmer
  component is a data-flow question (Step 5), not a conversion.

Everything else (`app/components`, `admin/components`, `app/ui-kit`, plugin `components/`
and `connectors/`, and the same directories in external plugins and themes) is in scope.
Inventory of what is left in core and bundled plugins:

```bash
grep -rlE '^import Component from "@ember/component"' frontend/discourse plugins --include='*.js' --include='*.gjs' | grep -vE 'node_modules|/dist/|/tests?/'
```

To pick what to convert next, `scripts/rank-targets.py` ranks that inventory by risk and
leaves out components already in open PRs; [PLAN.md](PLAN.md) covers how to read it and
how to batch.

Subclasses in core or plugins of the component you convert are in scope too; subclasses
in external checkouts are flagged.

## Step 1: pre-flight plan

Run the analysis script and read its output in full:

```bash
.skills/discourse-glimmer-conversion/scripts/analyze.sh path/to/component.gjs
```

It lists the classic features used, the declared class members, candidate args (reads of
`this.x` never declared or assigned), own state assigned but never declared, writes
(two-way binding candidates), template reads of `@args` and of `this.*`, call sites in
core and bundled plugins, class fields that call sites also pass as args, subclasses,
`modifyClass` hits, imports and patches in the external checkouts, and the tests and specs
that reference the component's resolver name, class name, or selectors. For a component in another
repo, pass its path; the script scans that repo plus core (set `CORE_DIR` when the core
checkout is not the one holding this skill). Then read the component and every call site
yourself; the script only greps.

**If the script reports no call sites and the file is not a connector, stop and check for
dead code before converting anything.** Connectors are rendered by the outlet system from
their directory path, so no call sites is normal for them; for everything else it means
either an indirect render path or a component nothing renders any more. Confirm with the
external checkouts (`<ClassName`, `component:<resolver>`, an import ending in the file's
basename — anchor the resolver pattern so `component:foo` does not match `component:foo-bar`).
When nothing renders it, the right change is to propose deleting the file, not to convert it.

Write a short plan (in your reply, not a file) with:

- **Args**: name, who passes it, whether it has a class-field default (a classic class
  field is overridable by an arg of the same name; the Glimmer form is
  `this.args.x ?? default`).
- **Own state**: fields the component mutates; which need `@tracked` (read by the template,
  by a getter the template reads, or by a modifier/`helperFn` that must re-run on it).
- **Shape**: class or template-only. The script prints "(none: expect a template-only
  component ...)" under declared members when the class has no members; confirm the
  "this.* reads in template" section is empty too.
- **Two-way bindings**: each arg written by the component, who reads it back, chosen
  redesign (see Step 5).
- **Wrapper**: tag, static classes, class bindings, attribute bindings, id, element event
  methods.
- **Lifecycle**: each hook and its replacement, one concern at a time (Step 4).
- **Consumers to edit** and **consumers to flag** (external).
- **Tests to convert or add.**

## Step 2: class and state

Do these in order inside the file; each one removes a dependency of the next.

1. **Observers first.** `@observes` cannot live on a Glimmer class, and in this app
   observers are async and keep firing for tracked changes, so a half-converted file
   misbehaves in confusing ways. Each observer becomes a getter (when it derived state), a
   `modifier()` reading the arg (when it touched the DOM), a `helperFn` (autotracked effect
   without an element), or an event handler (when it only reacted to user input). A
   replacement that writes tracked or model state must defer the write (`schedule`, `next`,
   or the existing debounce); see Step 4.
2. **Computeds to getters.** `@computed("a", "b") get x()` → `get x()`. Drop the dependency
   list; autotracking replaces it. Add `@cached` only when the getter is expensive or
   returns a fresh object/array whose identity matters (`{{#each}}`, args to children).
   A `@computed` getter with a `set x(v)` pair becomes a plain accessor pair.
3. **Own state.** `this.set("x", v)` / `setProperties` / `toggleProperty` become
   assignments; declare the field, and decorate it `@tracked` when the template, a getter
   the template reads, a modifier, or a `helperFn` must react to it. Leave other fields
   plain. The lint rule `discourse/no-unnecessary-tracked` only catches `@tracked` fields
   that are never written; a written-but-unrendered field is your call.
4. **Args.** Every remaining `this.x` that is not declared on the class is an arg:
   `this.args.x` in JS, `@x` in the template. A class field that callers also pass becomes
   `get x() { return this.args.x ?? DEFAULT; }` (or a `@tracked` local seeded from the arg
   when the component mutates it; see data-flow reference).
5. **Reads across the tracking boundary.** Autotracking only sees reads that consume a
   tag. In a getter, modifier, or `helperFn` body, `model.x` is tracked only when the model
   declares `x` as `@tracked`/`@trackedArray` or as a `@computed` getter. A plain field on an
   `EmberObject`, `RestModel`, or POJO is not, even though `set()` dirties it, so a getter
   over it goes stale; template paths (`{{@model.x}}`) do track plain fields. When
   `@computed("model.x")` becomes a getter, declare `x` `@tracked` on the model (classic
   `set()` writers keep working) or read with `get(model, "x")` when the model cannot
   change; check the model before assuming the getter updates. `this.get("a.b")` on own
   state becomes `this.a?.b`.
6. **Actions.** `actions: {}` entries and `this.send("x")` become `@action` methods called
   directly. `sendAction("name")` becomes `this.args.name?.()`. Methods passed to
   `appEvents.on`/`off`, `addEventListener`, or modifiers need a stable identity: keep or
   add `@bind` (or `@action`).
7. **Mixins and base classes.** `Component.extend(Mixin)` becomes composition (a helper
   class instance as a field, or a modifier). `Component.extend({...})` object bodies become
   class members.
8. **Base import last.** `import Component from "@glimmer/component"`; `init` moves to
   `constructor` (Step 4); drop the
   `/* eslint-disable ember/no-classic-components ... */` banner and the
   `@ember-decorators/*` imports. Reads of a name that `lib/implicit-injections.js` injects
   into classic components (`siteSettings`, `currentUser`, `site`, `appEvents`, `store`,
   `session`, `messageBus`, `capabilities`, ...) without an `@service` declaration need one;
   the script's "implicit injections read" line lists them.
9. **Empty class.** If nothing remains in the class body once Step 3 (wrapper) and Step 4
   (lifecycle) are done and the template reads no `this.*`, emit a template-only component
   (`const Foo = <template>...</template>; export default Foo;`, same name so imports and
   invocations stay), and drop the `@glimmer/component` import. Lint rejects an empty
   class (`ember/no-empty-glimmer-component-classes`, no autofix). A template that reads
   `this.siteSettings`, `this.currentUser`, or `this.site` keeps the class with `@service`.
   A template-only export makes an external `extends` throw at import time and turns an
   external `modifyClass` into a silent no-op; when the script found such a consumer, keep
   the empty class with `// eslint-disable-next-line ember/no-empty-glimmer-component-classes`
   naming that consumer, and list it in the report. In-tree subclasses were folded in
   Step 0; `{{component "foo"}}` string lookups keep working either way.

## Step 3: wrapper element and element events

| Classic | Template |
|---|---|
| no `tagName` | `<div ...attributes>` around the whole template |
| `@tagName("x")` | `<x ...attributes>` |
| `@tagName("")` | no wrapper; the template is the fragment. Keep any `...attributes` already present |
| `@classNames("a", "b")` | `class="a b"` |
| `@classNameBindings(":static", "flag:on:off", "other")` | `class={{dConcatClass "static" (if this.flag "on" "off") (if this.other "other")}}` for boolean `other`; a string- or number-valued bare binding adds the value itself: `this.btnType` |
| `@attributeBindings("role", "computedTitle:title")` | `role={{this.role}} title={{this.computedTitle}}` |
| `elementId = "x"` / `this.set("elementId", ...)` | `id="x"` / `id={{this.id}}` |
| `click(e)`, `keyDown(e)`, `focusIn`, `focusOut`, `change`, `submit`, `dragOver`, `touchStart` | `{{on "click" this.click}}` etc. on the wrapper. When the wrapper is not interactive, add `{{! eslint-disable ember/template-no-invalid-interactive }}` inside `<template>` above it |
| `@tagName` supplied by callers | `dElement` when callers genuinely vary it; otherwise fix the tag and change the callers |

Rules: attributes callers may override go before `...attributes`, attributes the component
owns go after it; `class` merges either way. Grouping of attributes, `@arguments`, and
modifiers on the new element follows `discourse-frontend-conventions` Step 4. Classic
element handlers also received bubbled events from descendants, so the wrapper is the
right target. `{{on}}` neither calls `preventDefault` nor honors `return false`; a classic
handler returning `false` got both `preventDefault()` and `stopPropagation()`, so add the
calls the old behavior relied on. Caller-side `@classNames=`, `@class=`, `@id=`, `@elementId=`, `@tagName=` become plain
attributes.

## Step 4: lifecycle

| Classic | Glimmer |
|---|---|
| `init`, `@on("init")` | `constructor` (after `super(...arguments)`) or field initializers |
| `didInsertElement`, `@on("didInsertElement")`, `this.element` | a `modifier()` class field applied to the wrapper or the specific element; it receives the element and returns a cleanup function |
| `willDestroyElement`, `didDestroyElement` | the cleanup returned by that modifier. It runs after the element is detached but still holds the node, so listener removal and third-party `destroy()` work; layout reads and ancestor lookups do not |
| `willDestroy` | `willDestroy()` with `super.willDestroy(...arguments)`, or `registerDestructor(this, fn)`; for non-DOM teardown (`appEvents.off`, MessageBus, timers). Runs after all modifier cleanups |
| `didReceiveAttrs` | `@resettableTracked x = this.args.x` when local state must reset on arg change; a getter (`@cached` when it builds a fresh object or collection) when it only derived; a modifier when it touched the DOM |
| `didUpdateAttrs`, `didUpdate`, `didRender` | a modifier that reads the args it cares about (modifier args are lazy: read them in the body or they do not re-run); `{{#each (array @model) key="id"}}` when the whole subtree must rebuild on identity change |
| `willRender`, `willUpdate`, `willClearRender` | usually dead once computeds are getters; otherwise a modifier |
| `schedule("afterRender")` / `scheduleOnce` for post-render DOM work | keep inside the modifier, or `@afterRender` (already guards destruction) |
| `!this.element \|\| this.isDestroying \|\| this.isDestroyed` | `this.isDestroying \|\| this.isDestroyed` |
| `$(window).on("click.ns")` / document click listeners for click-outside | `dCloseOnClickOutside` modifier |
| `matchMedia` / resize listeners driving state | `TrackedMediaQuery` (`discourse/lib/tracked-media-query`) read from a getter, or `dOnResize` |

A `modifier()` body autotracks every synchronous read and re-runs, after its cleanup,
whenever any of it changes. So split by concern, not by element: **one modifier per
reactive concern** (each old `@observes`/`didUpdateAttrs`, reading exactly the values it
should react to) and a separate mount-once modifier for the `didInsertElement` +
`willDestroyElement` work. The mount-once modifier must not read a value that changes
while the element lives (a model `@computed`, a service getter, a changing arg) or it
tears its listeners down and re-adds them on every change. Triage each read of the old
insert hook: a value the component reacts to elsewhere belongs to that concern's modifier
or `helperFn`, whose first run replaces the insert-time kick; a value read once to decide a
mount-only action (focus, caret, initial scroll) is read inside `untrack(() => ...)`, or
behind an instance flag (`ui-kit/modifiers/d-auto-focus.js`), or snapshotted into a plain
field in the constructor. Passing it as a modifier arg does not help: modifier args are
lazy, so an unread arg is unusable and a read arg is tracked.

Never write tracked state that the same template already read from inside a getter, a
modifier body, or a `helperFn` body; that is the backtracking-rerender assertion. Defer
with `schedule("afterRender")` or `next`, or derive instead of writing.

## Step 5: data flow and call sites

This is the only step that changes the public interface. For each arg the component
writes (`this.set("arg")`, `set(this, "arg")`, assignment, `toggleProperty`,
`setProperties`, `<Input @value={{this.arg}}>`, or passing it to an arg-mutating component
without `@onChange`):

1. Nobody reads it back → drop the write; the state becomes local `@tracked`.
2. The parent reads it back → add a callback arg named for the event (`@onChange`,
   `@onSelect`, `@onExpandToggle`; `@setX` when there are several plain setters). A classic
   caller passes `{{fn (mut this.x)}}` or an existing action; a Glimmer caller passes an
   `@action` that assigns a `@tracked` field (add one if none exists); a Glimmer component
   that only relays the arg forwards the callback unchanged.
3. The write targets a property *of* an arg (`this.set("model.x")`) → not a two-way binding.
   Keep it as `this.args.model.set("x", v)` (EmberObject) or assignment (tracked model).
4. The component needs an editable local copy → `@tracked _x` with
   `get x() { return this._x ?? this.args.x; }`, or `@resettableTracked` when it must follow
   later arg changes.

Then update every call site: `<Foo @x=...>` invocations, `{{component "foo"}}` string
lookups, `<this.dynamic>` maps, and outlet args. Bundled plugins are edited in the same
change. External plugins and themes are not edited; list each with the exact edit needed.
Full recipes in the data-flow reference, including `<Input>`/`<Textarea>`, select-kit, and
`{{yield}}`ed values.

## Step 6: plugin outlets and the plugin API

- **A Glimmer connector receives each outlet arg as a plain argument.** `plugin-outlet.gjs`
  renders connectors through `curryComponent(componentClass, outletArgs, owner)`, so an
  outlet arg `topic` arrives as `@topic` / `this.args.topic`, and the whole hash is also
  passed as `@outletArgs`. Prefer the plain form when converting: `@topic`, not
  `@outletArgs.topic`. (Classic connectors only ever had `this.topic`, and a name clash with
  a class property triggered the `discourse.plugin-outlet-classic-args-clash` deprecation;
  Glimmer has no such clash.)
- A component that *renders* a `PluginOutlet` must pass its own state correctly:
  `@outletArgs={{lazyHash topic=this.topic}}` becomes `topic=@topic` for an arg, since
  `this.topic` is `undefined` on a Glimmer component and fails silently.
- A classic connector's `@tagName`/`@classNames` became an implicit wrapper; give the
  connector an explicit wrapper element with the same classes.
- `api.modifyClass("component:<name>")` patches reach into the prototype you are rewriting
  (`this.foo` → `this.args.foo`, hooks removed). Keep the file path and name unchanged. A
  patch in a bundled plugin is in-tree: update it in the same change (rewrite it against
  `this.args` and modifiers, or fold it into the component). A patch in an external
  checkout is flagged with what breaks.

## Step 7: tests

- If the component's integration test still uses an `hbs` string or is a `.js` file,
  convert it to `.gjs` with an inline `<template>` and a real import. Otherwise leave
  passing tests alone, including ones that use `this.set`. If there is no integration test,
  add one covering the wrapper, each redesigned binding, and each lifecycle replacement, or
  state in the report which acceptance tests are the coverage.
- New tests follow `discourse-writing-js-tests`; the pattern for outer mutable state (a
  local tracked class, assign, `await settled()`) is in the consumers-and-tests reference.
- Objects the component mutates through an arg must be reactive in the test
  (`trackedObject(...)` from `@ember/reactive/collections`), and the test asserts the
  write reached the caller.
- Any implicit default the classic version created (`if (!this.status) this.set("status",
  {})`) must now be passed by the test, or reinstated as a getter default.
- Add a reactivity test for every redesigned two-way binding, for every arg that a
  `didReceiveAttrs`/`didUpdateAttrs` used to watch, and for every class-field default
  that callers override with an arg.
- Acceptance and system tests that assert on the old wrapper's classes or on markup that
  changed need updating; the script lists them by selector.

## Step 8: verify

```bash
bin/lint --fix path/to/component.gjs path/to/changed/callsites... path/to/tests...
bin/qunit path/to/component-test.gjs        # by PATH, once per component in a batch
bin/qunit frontend/discourse/tests/acceptance/<each file the script listed>.js
bin/rspec spec/system/<each spec the script listed>
```

Run each component's own test file **by path**, not through `--filter`: module names are
PascalCase (`Integration | Component | WatchedWordUploader`), so a word-spaced filter like
`--filter "watched word"` silently matches nothing and the run looks green. The script lists
the test files; run every one.

Then read the pitfalls reference and check each item against your diff. Confirm no
`ember/no-classic-components`, `ember/no-observers`, `ember/require-tagless-components`,
`ember/no-actions-hash`, `ember/no-on-calls-in-components`,
`ember/no-empty-glimmer-component-classes`, or `sort-class-members` errors remain, and
that `discourse/no-unnecessary-tracked` did not warn. When the component is DOM-heavy
(uploads, editors, drag, scroll), open the page in the running app and exercise it.

## Step 9: report

The reply must contain:

- what changed at the interface (renamed or added callback args, removed arg writes,
  dropped implicit defaults), with each call site edited;
- external consumers found (`modifyClass`, imports, subclasses) with the edit each needs;
- pre-existing bugs found, and whether each was fixed (same-or-less code) or preserved;
- behavior you could not preserve, if any, and why;
- the test and lint output.

## Step 10: branch, commit, PR

The standard flow for a conversion, once the report is written and the user has asked for it
(never commit or push unprompted):

**Ten components per PR.** Convert them one at a time — each gets its own pre-flight, plan,
and verification — then ship the batch as a single commit and a single PR. A batch is only
for components that are independent of each other; anything that changes a call site another
batch member also touches goes in its own PR. Drop a component from the batch rather than
rushing it: one that turns out to need a data-flow decision, a plugin-API change, or a test
rewrite is worth its own PR, and the next candidate on the list takes its place.

```bash
git checkout -b 0-glimmer-batch-<n> origin/main     # single component: 0-glimmer-<file-name>
git add <the converted components and their call sites>
git commit -F /tmp/commit-msg.txt                   # subject + the shared body below
git push -u origin 0-glimmer-batch-<n>
gh pr create --draft --base main --title "<subject>" --body-file /tmp/pr-body.md
gh pr edit <number> --add-label glimmer-conversion
```

Then update [PROGRESS.md](PROGRESS.md), the running log of conversion PRs, and commit it with
the skill (not with the conversion). It is a two-level list: the PR on the first level, its
components on the second. [PLAN.md](PLAN.md) covers picking the next targets.

```markdown
- [#43521](https://github.com/discourse/discourse/pull/43521) ✅
  - admin/admin-report-table-row
  - categories-and-latest-topics
  - plugins/discourse-subscriptions/connectors/subscriptions-campaign
```

1. **Append one first-level entry per PR**, then one second-level entry per component it
   converts. The component label is the file path simplified to what identifies it:
   `badge-title`, `admin/setting-validation-message`, `ui-kit/d-tap-tile`,
   `plugins/chat/collapser`, `plugins/discourse-assign/connectors/assigned-list` (keep
   `connectors/` — a plugin can have a component and a connector of the same name).
2. **Then tick approved PRs.** For every first-level entry with no emoji, check
   `gh pr view <num> --json reviewDecision --jq .reviewDecision`; when it is `APPROVED`,
   append ` ✅` to that entry. Do this on every append so the log stays current.


Branch from `origin/main`, not from whatever branch the work happened on, so unrelated
commits stay out of the PR; check first that the converted file is identical on both
(`git diff origin/main HEAD -- <file>`). Commit only the conversion; leave unrelated
working-tree changes alone.

**Open the PR as a draft** (`--draft`); the user marks it ready for review.

**The commit and the PR carry the same title and the same body.** Write the body to one
file and use it for both (`git commit -F`, `gh pr create --body-file`) so they cannot
drift. No attribution trailers. Label the PR `glimmer-conversion`.

Subject, single component: `DEV: Convert <ComponentName> to a glimmer component`, or
`DEV: Modernize <ComponentName> component` when the change went beyond the conversion
(call-site interface changes, a fixed bug). Batch: `DEV: Convert <n> components to glimmer`.

Body: the fixed opening sentence, then the component inventory as a bullet list of **class
names grouped by origin** — core components on their own line, each plugin on its own line
suffixed with the plugin's directory name in parentheses. Then, after a blank line, a plain
sentence for anything specific to a conversion:

```
Done with the help of our glimmer conversion skill.

* AdminReportTableRow, CategoriesAndLatestTopics, CategoriesAndTopTopics
* SubscriptionsCampaign, SubscriptionsCampaignSidebar (discourse-subscriptions)

`AdminReportTableRow` reads `options` directly from args instead of a class field.
```

The bullets are the inventory and nothing else. The trailing sentences cover only what is
specific: a service injection the classic component got implicitly, a dropped default, a
redesigned two-way binding and its new callback, a call-site interface change, a
pre-existing bug fixed, a behavior deliberately preserved that looks wrong. Leave out the
mechanics every conversion performs (the base-class swap, `init` → `constructor`,
`this.set` → `@tracked`, args moving to `@args`, a dropped `@tagName`); the title says the
component was converted and the diff shows the rest. Never mention what did *not* need
changing. When nothing is specific, the body is the sentence plus the inventory. Detail too
long for one sentence — external consumers needing a follow-up, behavior you could not
preserve — goes in the reply to the user, not in the commit.

## Improving this skill

This is a living skill. After each conversion, add anything the skill did not predict to
the matching reference: a new classic pattern to `feature-mapping.md`, a new data-flow
shape to `data-flow.md`, a regression or surprise to `pitfalls.md` with the commit that
shows it. Keep `SKILL.md` procedural and short; details live in the references. Update
`scripts/analyze.sh` when a grep misses a consumer category.
