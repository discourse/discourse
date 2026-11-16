# Pitfalls: regressions past conversions caused

The evidence behind the rules: each entry is a real regression or surprise from this repo's
history, with the commit that shows it. Where a step already states the rule, the entry is a
one-line pointer to it. Check every item against your diff before reporting done; SKILL.md's
"Improving this skill" says when to add one.

## Args and defaults

- **A classic class field is silently overridable by an arg of the same name** (SKILL.md
  Step 2.4): `CreateTopicButton` ignored every caller's `@label` (`3a945f3663c` →
  `cddc96e9c01`).
- **`this.foo` left in `@outletArgs`/`lazyHash` renders `undefined`** (SKILL.md Step 6;
  `dd329d55a52` → `323013d9c79`).
- **Implicit defaults a hook created vanish** (SKILL.md Step 7; `c96dce29348`).
- **Angle-bracket string coercion.** `@triggerAppEvent="true"` was a string; when the
  Glimmer version compares with `=== true` it must become `@triggerAppEvent={{true}}`
  (`d6d3fc86294`).
- **Caller-side `@classNames`, `@class`, `@id`, `@tagName` stop doing anything** (SKILL.md
  Step 3; `4e417223e5d`, `d6d3fc86294`).
- **A child's default delimiter can be the stored format.** `url-list` gave `ValueList` no
  `@inputDelimiter`, so `ValueList` joined on its `"\n"` default, and the server splits
  `default_avatars` on `"\n"` (`User`). Every other list setting is `"|"`-joined. When a
  conversion moves the join into the component's callback, check what the server splits on
  instead of copying the family's `"|"`.
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
- **`?.` is not a truthiness check.** Callers and tests pass `false` as well as nothing
  (`<PaymentOptions @plans={{false}} />`). The classic `if (this.plans)` skipped it;
  `this.args.plans?.toSorted(...)` throws, because `false` is not nullish. Keep the classic
  guard's truthiness when the arg can be a boolean.
- **Keep the `/** @type */` on a member that survives the conversion**, even when its
  initializer changes (`newEmojiGroups` lost it); drop it with a member that becomes an arg,
  and annotate new public members initialized to `null` or `[]`. Why the declared types
  matter is `discourse-writing-typescript` golden rule 3; `lint:types` cannot catch a
  dropped one, because `.gjs` bodies are not type-checked (`#44656`).
- **Seeding tracked state from an arg is a snapshot however it is written.**
  `ember/no-tracked-properties-from-args` flags `@tracked x = this.args.x` but not
  `@tracked period = periodString(this.args.model.leaderboard.default_period)`, nor the same
  assignment in a constructor. `GamificationLeaderboard` stays mounted across
  `/leaderboard/:id`, so a snapshot keeps the previous leaderboard's period. Use
  `@resettableTracked` for a local copy seeded from an arg.

## Reactivity

- **A `.gjs` file that still extends `@ember/component` has non-tracked args.** Category
  title links went stale for theme users because the component was moved to `.gjs` without
  changing the base class; fixing the bug *was* the conversion (`92312eec7b1`).
- **Half-converted reactivity chains fail silently** (golden rule 7; `4acd9c67535`,
  `11fac4c6bca`).
- **Dot-access reads of plain model fields do not track** (SKILL.md Step 2.5; `3f7cf1139da`).
- **Observers keep firing after you make things tracked** (SKILL.md Step 2.1).
- **Backtracking rerender** from writing already-read tracked state in a getter or
  modifier body (SKILL.md Step 4).
- **`@cached` getters returning a new tracked collection** must be keyed on the arg that
  should reset them, and the collection must be built inside the getter (`4e417223e5d`,
  `3f7cf1139da`).
- **Per-model reset state leaked across models.** Classic `didUpdateAttrs` reset per-arg
  state; the Glimmer version forgot to, so claimed/edited flags leaked from one reviewable
  to the next. Fix: `@cached get state()` keyed on `this.args.reviewable`, or
  `@resettableTracked` (`3f7cf1139da`).
- **Deprecated array extensions still work.** `firstObject`, `lastObject` and friends resolve
  through `app/array-shim.js` with a deprecation even though `EXTEND_PROTOTYPES` is off, so
  `aliasLevelOptions.firstObject.value` in a classic getter is not a bug. Switch to `[0]`
  while converting but do not report it as a fix (`GroupsFormInteractionFields`; a mutation
  run caught the false claim).
- **An observer attached after the service set its state never sees that state.**
  `GlobalNotice` called `logsNoticeService.addObserver("text", ...)` in its constructor. That
  was the service's first lookup, and the service's `init` had already restored the stored
  text, so a stored error-rate notice never came back after a reload. When replacing such
  observers, derive the value in a getter from the service's (computed, so tracked) property
  instead of copying it on change.
- **`this.args` in a classic component is `undefined`.** `RagUploader` read
  `this.args?.allowImages`, so the picker never accepted images. A `this.args` read in a
  classic file is a bug to note in the report, not a sign that the file is half converted.

## Lifecycle and DOM

- **`{{didUpdate fn}}` without the arg never fires.** It re-runs only when the arguments
  passed to the modifier itself (positional or named) change; the element's attributes and
  children do not count. A custom `modifier()` that reads the arg in its body avoids the
  trap; that is one reason the lint policy calls render-modifiers an anti-pattern.
- **Modifier args are lazy** (SKILL.md Step 4).
- **A mount-once hook moved into one modifier re-runs on every value it read** (SKILL.md
  Step 4; the composer-title case is in feature-mapping's Lifecycle section).
- **Teardown order is modifier cleanups, then `willDestroy`** (SKILL.md Step 4's table).
- **Classic handlers caught bubbled events and `return false` prevented the default;
  `{{on}}` does neither** (SKILL.md Step 3; `dd329d55a52`, `0c1a658f28c`, `41593a5d7d3`).
- **`@on("willDestroyElement")` decorators are easy to miss** in a long file; grep for
  `@on(` and `@ember-decorators/object` before declaring the lifecycle done
  (`8a09fd370a6`).
- **IntersectionObserver/ResizeObserver replacements do not fire deterministically under
  test** (consumers-and-tests, "Acceptance and system tests"; `7b062e24def`).

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
- **A call where a callback belongs.** `.finally(this.set("formSubmitted", false))` ran the
  `set` immediately, so `WatchedWordForm` never stayed disabled while saving. When rewriting
  `this.set` into assignments, check that each one passed as an argument sits inside a
  function.

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
- **A blanket `this.` → `@` template rewrite also catches the component's own members.**
  `PaymentPlan`'s `@action={{this.planClick}}` became `{{@planClick}}`, an arg nobody passes,
  so clicking a plan did nothing; no test clicked one (`3dd5c4039d3`, fixed in the next
  batch that touched the caller). After rewriting, run `scripts/self-args.py <files>`: it
  lists template `@name` reads that match a member of the same class.

## Consumers

- **`modifyClass("component:x")` patches the prototype you rewrote.** Hooks and `this.foo`
  args the patch relies on disappear. External plugins and themes patch `composer-body`,
  `d-editor`, `d-navigation`, `topic-title`, `topic-progress`, `topic-footer-buttons`,
  `search-result-entry`, `directory-item`, `composer-editor`, `composer-actions`, and more.
  Keep the file path, keep the name, and list each hit in the report.
- **Renaming or moving the file changes the resolver name**, so `modifyClass` patches are
  dropped. Never rename; the `.gts` extension change and its importer trap are in SKILL.md
  Step 1.
- **External subclasses of the converted class** get a Glimmer base under a classic body.
  Select-kit bases (`ComboBoxComponent`, `DropdownSelectBoxComponent`,
  `SelectKitRowComponent`, `MultiSelectComponent`) and `UserCardContents` are subclassed
  externally; select-kit is out of scope for this skill. When the external subclass only
  *reads* the base (its own template uses `this.date`, `this.showTime`, the base's actions),
  keep the base's former class fields as same-named getters (`get date() { return
  this.args.date; }`, with a one-line comment saying subclasses read them). The skill
  already turns overridable fields into getters; naming them as before keeps such a subclass
  rendering, and only its own reads of caller args (`this.tabindex` → `this.args.tabindex`)
  need a follow-up (`DDateTimeInput`, discourse-custom-wizard).
- **A bundled plugin's `modifyClass` that adds `classNameBindings`** has nothing to bind to on
  a Glimmer wrapper. A class on the row is a contract: before replacing it, search every
  `all-the` checkout (with `command grep`) for the class. discourse-ai's `ai-result` looked
  like styling for its own icon, but a private plugin's search analytics and CSS select
  `.search-results .ai-result`. Keep the class with a `<component>-class` value transformer
  (`applyValueTransformer("search-result-entry-class", [], { post })` into `dConcatClass`,
  registered in `lib/registry/transformers.js`, plugin moved to `registerValueTransformer`);
  passing `post` to the existing outlet so the plugin's connector renders only for AI posts is
  a separate cleanup on top (`SearchResultEntry`).
- **Non-colocated `templates/components/*.hbs` in themes/plugins** are served by a
  classic backing class from `instance-initializers/component-templates.js`; converting a
  core component that such a theme template *overrides* changes what the theme gets
  (`8f52b81efa7`).

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
