# Pitfalls: regressions past conversions caused

Each entry is a real regression or surprise from this repo's history, with the commit that
shows it. Check every item against your diff before reporting done. Add new ones at the
end of the matching section with the commit sha.

## Args and defaults

- **A classic class field is silently overridable by an arg of the same name; a Glimmer
  field is not.** `label = "topic.create"` on the classic `CreateTopicButton` accepted
  `@label` from callers; after conversion every caller's label was ignored. Fix was
  `this.args.label ?? "topic.create"` (`3a945f3663c` → `cddc96e9c01`). Check every class
  field with a default against the call sites' arg names.
- **`this.foo` left behind in `@outletArgs` / `lazyHash`.** `@outletArgs={{lazyHash
  topic=this.topic}}` renders `undefined` on a Glimmer component without any error; it
  must read `@topic` (`dd329d55a52` → `323013d9c79`).
- **Implicit defaults created in a hook vanish.** `didInsertElement` doing
  `if (!this.status) this.set("status", {})` has no equivalent; either reinstate as a
  getter default or make callers (and tests) pass the value (`c96dce29348`).
- **Angle-bracket string coercion.** `@triggerAppEvent="true"` was a string; when the
  Glimmer version compares with `=== true` it must become `@triggerAppEvent={{true}}`
  (`d6d3fc86294`).
- **Caller-side `@classNames`, `@class`, `@id`, `@tagName` stop doing anything.** Convert
  them to plain attributes at every call site and make sure the wrapper has
  `...attributes` (`4e417223e5d`, `d6d3fc86294`).
- **A class field the callers also pass is often two-way, not just overridable.** The script
  prints these under "class fields that call sites also pass as args" and the obvious reading —
  "a default the arg overrides" — is only half of it. `AdminEditableField` declared
  `editing = false` and did `toggleProperty("editing")`; every call site passed
  `@editing={{@controller.editingUsername}}`, and the controller's save handler ended with
  `.finally(() => this.toggleProperty("editingUsername"))`. So the flag was *shared*: the
  component opened edit mode, the controller closed it. Converting `editing` to local
  `@tracked` state left the controller toggling a flag nobody read, and the field never left
  edit mode after a save. Fix: the caller owns the flag (`@editing` drives the template) and
  the component reports intent through a callback (`@toggleEditing`). For each such field,
  check whether a *consumer* writes the same property before deciding it is own state.
- **A dependency key with no matching read is a bug left by the `@discourseComputed`
  migration.** `@discourseComputed("text", "textParams")` passed both to the body as
  positional arguments; `a2e64d4b458` rewrote the bodies to read `this.x` and any argument
  beyond the first was dropped, leaving the now-inert key in the decorator.
  `DiscourseLinkedText` called `i18n(this.text)` while still declaring `textParams`, so
  `pwa.install_banner`'s `%{title}` never interpolated. When a `@computed` key is never read
  in the getter, check the pre-`@computed` version before assuming it is dead weight.

## Reactivity

- **A `.gjs` file that still extends `@ember/component` has non-tracked args.** Category
  title links went stale for theme users because the component was moved to `.gjs` without
  changing the base class; fixing the bug *was* the conversion (`92312eec7b1`).
- **Half-converted reactivity chains fail silently.** A classic `@filter` macro on a model
  reading a `@trackedArray`, or `@discourseComputed` reading a native getter, does not
  update. Either convert the whole chain or bridge with `@dependentKeyCompat`
  (`4acd9c67535`, `11fac4c6bca`).
- **Dot-access reads of plain model fields do not track.** In a getter, modifier, or
  `helperFn` body, `model.x` is tracked only when the model declares `x` as
  `@tracked`/`@trackedArray` or as a `@computed` getter; a plain field on an `EmberObject`,
  `RestModel`, or POJO is not, even though `set()` dirties it (only `get()` and template
  paths consume the tag). A `@computed("model.x")` turned into
  `get x() { return this.args.model.x; }` renders once and never again. Declare `x`
  `@tracked` on the model (`3f7cf1139da`) or read with `get(model, "x")`, and check the
  model before assuming the getter updates.
- **Observers keep firing after you make things tracked.** This app runs observers
  async, so an `@observes` on a still-classic class fires a runloop later for `@tracked`
  changes too; a half-converted file gets stale double updates. Remove observers first.
- **Backtracking rerender.** Writing tracked state from a getter or from a modifier body,
  when the template already consumed that state, throws "You attempted to update `x` on
  `y`, but it had already been used previously in the same computation". Common sources:
  a `didInsertElement` that set a flag which the template also read, moved into a modifier
  verbatim. Defer with `schedule("afterRender")`, or derive instead of writing.
- **`@cached` getters returning a new tracked collection** must be keyed on the arg that
  should reset them, and the collection must be built inside the getter (`4e417223e5d`,
  `3f7cf1139da`).
- **Per-model reset state leaked across models.** Classic `didUpdateAttrs` reset per-arg
  state; the Glimmer version forgot to, so claimed/edited flags leaked from one reviewable
  to the next. Fix: `@cached get state()` keyed on `this.args.reviewable`, or
  `@resettableTracked` (`3f7cf1139da`).

## Lifecycle and DOM

- **`{{didUpdate fn}}` without the arg never fires.** It re-runs only when the arguments
  passed to the modifier itself (positional or named) change; the element's attributes and
  children do not count. A custom `modifier()` that reads the arg in its body avoids the
  trap; that is one reason the lint policy calls render-modifiers an anti-pattern.
- **Modifier args are lazy.** A `modifier((el, [x]) => {...})` that never reads `x` does
  not re-run when `x` changes.
- **A mount-once hook moved into a modifier re-runs on every value it read.**
  `didInsertElement` code moved verbatim into one `modifier()` re-runs, with cleanup,
  whenever anything it read changes: composer-title reads `composer.titleLength` (dirtied
  on every keystroke) and `focusTarget` (a service getter), so as one modifier it would
  tear down its listeners and call `putCursorAtEnd` on each keystroke. One modifier per
  concern; wrap one-shot reads in `untrack()` (`ui-kit/d-decorated-html.gjs`), guard them
  with an instance flag (`ui-kit/modifiers/d-auto-focus.js`), or snapshot the value.
- **Teardown order is modifier cleanups, then `willDestroy`, then `isDestroyed`.** Both run
  after the element is detached, but only the modifier cleanup still holds the node:
  `removeEventListener` and third-party `destroy()` go there, and layout reads or ancestor
  lookups work in neither. `willDestroy` is for `appEvents.off`, MessageBus, timers.
- **Classic element handlers caught bubbled events.** `click(e)` on the component fired
  for clicks on any descendant. `{{on "click"}}` on a specific child changes the target
  set; put it on the wrapper unless the handler already narrowed with `e.target.closest`
  (`dd329d55a52`, `0c1a658f28c`).
- **`{{on}}` does not `preventDefault` and ignores `return false`.** `{{action}}` and
  classic `click() { ...; return false; }` did. Add `event.preventDefault()` where links
  or forms depended on it (`41593a5d7d3`).
- **`@on("willDestroyElement")` decorators are easy to miss** in a long file; grep for
  `@on(` and `@ember-decorators/object` before declaring the lifecycle done
  (`8a09fd370a6`).
- **Tests that do not fire observers.** IntersectionObserver / ResizeObserver based
  replacements do not fire deterministically under test; `load-more` needed exported
  test toggles (`7b062e24def`). Prefer `TrackedMediaQuery` / `dOnResize` and assert on the
  state, not on timing.

## The component as a receiver

- **Handing `this` to a helper or plugin API can make the conversion impossible.**
  `anonymous-topic-footer-buttons` scored as the easiest component in the whole inventory,
  but it calls `getTopicFooterButtons(this)`, and that function does
  `legacyDependentKeys.forEach((k) => context.get(k))` and `field.apply(context)` on the
  component it is handed. A Glimmer component has no `get()`, and core plus external
  plugins do register buttons with `dependentKeys`, so the converted component throws on
  render; the registered callbacks also read `this.topic`, which moves to `this.args.topic`.
  Converting it means reworking the plugin API first. `analyze.sh` flags a bare `this`
  passed to a function (framework helpers like `getOwner(this)` and
  `registerDestructor(this, …)` are filtered out); read the callee before converting.
- **`this.foo()` → `this.args.foo()` changes the callback's receiver.** On a classic
  component an arg callback was a property of the component, so calling it set `this` to
  the component; through `this.args` it sets `this` to the args object. Production callers
  are usually unaffected because `@action` binds them, but anything relying on the receiver
  breaks. `WatchedWordUploader`'s test did: its `@done` callback was a plain `function`
  reading `this.uppyUpload.uppyWrapper`, which became `undefined` and failed with
  `Cannot read properties of undefined` after a 60s timeout, with no assertions run
  (batch PR #43534). Decide per case: `this.args.done.call(this)` preserves the old
  receiver exactly, but if only a test depends on it, fix the test to assert the real
  contract instead.

## Actions

- **`@action` inside an `actions: {}` hash is a silent no-op.** `39e1b97a5d1` fixed tag
  deletion that had never worked after a conversion left the hash in place. Remove the
  hash entirely; `ember/no-actions-hash` should catch it, so do not disable it.
- **String `@action="name"` (action bubbling) is unsupported.** DButton deprecated string
  actions in `a88902950af` and removed them in `2041eaf89db`; replace with a function.
- **`this.send("x")` to a parent controller/route.** Classic components could bubble to
  the route via `send`; Glimmer cannot. Pass the action in as an arg from the template that
  owns the route (`@controller.x`), or use `routeAction`.

## Templates

- **Inlining computed strings into the template drops characters.** A `.` went missing
  in `(concat "topic_statuses." entry.titleKey "help")` when five `@discourseComputed`
  string builders were inlined (`dd329d55a52` → `248501f4c7d`). Keep i18n key assembly in
  a getter when it has more than one part.
- **`{{#unless}}` + always-rendered fallback** rendered both branches
  (`dd329d55a52` → `94b309b05e0`). Use `{{#if}}...{{else}}`.
- **Whitespace control.** `{{~ ~}}` in the old template affected inline layout; keep it
  (`9874801f946`).
- **Markup shape changes break selectors** in acceptance and system specs
  (`.watched-word-form button` → `.btn-primary` after `<a onclick>` became `<DButton>`,
  `eccfc946f16`). Grep specs by class before changing markup, and prefer not changing it.
- **An implicit wrapper isolates its children from sibling selectors.** `reviewable-field`
  wrapped each field in an anonymous `<div>`, so the `.reviewable-user-details:not(:last-child)`
  border rule never matched a wrapped field while it did match the ones the parent inlined.
  Dropping the wrapper would have "fixed" the borders — a visual change nobody asked for.
  Before deciding a wrapper is dead weight, grep the scss for `:last-child`, `:first-child`,
  `+`, `~`, and `:nth-` on the classes its children carry.

## Consumers

- **`modifyClass("component:x")` patches the prototype you rewrote.** Hooks and `this.foo`
  args the patch relies on disappear. External plugins and themes patch `composer-body`,
  `d-editor`, `d-navigation`, `topic-title`, `topic-progress`, `topic-footer-buttons`,
  `search-result-entry`, `directory-item`, `composer-editor`, `composer-actions`, and more.
  Keep the file path, keep the name, and list each hit in the report.
- **Renaming or moving the file changes the resolver name**, so `modifyClass` logs
  `"component:x" was not found` and the patch is dropped. Never rename during a conversion.
- **External subclasses of the converted class** get a Glimmer base under a classic body.
  Select-kit bases (`ComboBoxComponent`, `DropdownSelectBoxComponent`,
  `SelectKitRowComponent`, `MultiSelectComponent`) and `UserCardContents` are subclassed
  externally; select-kit is out of scope for this skill.
- **Non-colocated `templates/components/*.hbs` in themes/plugins** are served by a
  classic backing class from `instance-initializers/component-templates.js`; converting a
  core component that such a theme template *overrides* changes what the theme gets
  (`8f52b81efa7`).

## Choosing a target

- **A component with no call sites is probably dead, not easy.** `group-member.gjs` looked
  like the single easiest conversion in the whole inventory (30 lines, `@tagName("")`, one
  action, no lifecycle) precisely because nothing rendered it. Seven non-connector classic
  components in core are unreferenced. Check reachability first; deleting beats converting.
- **Anchor resolver patterns when checking reachability.** `component:group-member` matches
  `component:group-member-dropdown`, which is a different component; the unanchored grep
  reported a dead component as live.
- **Connectors legitimately have no call sites.** The plugin-outlet system renders them from
  their directory path, so absence of invocations says nothing about them.

## Process

- **Reverts happened for build-tooling reasons**, not logic (`261ef8404ee` →
  `5d568d0bab1` → `0548f242081`); the reland dropped some optional chaining. If CI fails
  on a converted file in a way that looks like a build error, look at the reland diff.
- **The outletArgs-as-args change was reverted once for unexpected re-renders**
  (`707a91243c3` → `f8d61a341e0` → `3867c879ab8`). When a conversion makes a subtree
  re-render more often (a getter returning a fresh object each time), consider `@cached`.
- **`discourse-root` glimmerification was reverted the same day** (`27408c7e14b` →
  `9408ea44617`); root-level components that own event dispatching are not ordinary
  conversions.
