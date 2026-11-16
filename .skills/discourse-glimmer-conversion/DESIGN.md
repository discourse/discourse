# Design: `discourse-glimmer-conversion` skill

Working document for the skill that converts classic Ember components
(`@ember/component`) to Glimmer components (`@glimmer/component`). It records the
research, the decisions, and the intended shape of the skill so that it can be
iterated on as the skill is used on real conversions. It is not loaded by the skill.

## 1. Problem statement

- 142 classic components remain in core (80 `app/components`, 35 `admin/components`,
  15 `app/ui-kit`, 10 `select-kit`, 2 `app/lib` infra files) and 46 in bundled plugins
  (subscriptions 9, assign 6, gamification 4, chat 4, styleguide 3, poll 3, cakeday 3, ...).
  Counted as `import Component from "@ember/component"`; the wider grep for any
  `@ember/component` import also catches `{ Input }`/`{ Textarea }` importers, which are
  not conversions. Every one carries `/* eslint-disable ember/no-classic-components */`.
- All templates are already `<template>` in `.gjs`; there are no `.hbs` files left. The
  codemod that did that left the base class alone, so the remaining work is purely the
  class/data-flow migration, not file-format migration.
- The conversion is subtle because classic components conflate four things that Glimmer
  separates: args vs own state (`this.foo` for both), a wrapper element that is implicit
  and configured through class decorators, lifecycle hooks tied to DOM presence, and
  two-way bindings that let a child silently write into its parent.
- Lint policy already says what the destination is:
  `"ember/no-component-lifecycle-hooks": "off" // ... classic components should be converted
  to glimmer wholesale instead`, `"ember/no-at-ember-render-modifiers": "off" // TODO: ...
  considered an anti-pattern`, `@discourseComputed` marked `@deprecated`, and the
  `discourse/no-computed-macros` / `discourse/no-discourse-computed` autofixers.

## 2. Non-negotiables (from the brief)

1. Result uses `@tracked` + native getters/setters. No `@computed`, no observers.
2. Lifecycle hooks replaced by Glimmer-compatible mechanisms.
3. The wrapper element is reproduced in the template when the component had one.
4. Every call site and consumer is found and updated; two-way-bound args are redesigned
   case by case (DDAU), never mechanically.
5. Minimal viable change. Pre-existing bugs: fix only if the fix is the same amount of
   code or less; otherwise flag in the report.

## 3. Feature frequency in the remaining classic components

Counts are "files using" across the 188 remaining components, from grep. They set the
priority of the mapping reference: the top rows must be airtight, the bottom rows can be
short.

| Feature | Files | Feature | Files |
|---|---|---|---|
| `tagName` (145 of them `@tagName("")`) | 163 | `@observes` | 13 |
| `@computed(` (with dep keys) | 92 | `didReceiveAttrs` | 11 |
| `this.set(` | 63 | `@bind` | 11 |
| `didInsertElement` | 34 | `attributeBindings` | 10 |
| `init()` | 26 | `this.appEvents.on` | 9 |
| `this.element` | 25 | `keyDown(` | 7 |
| `willDestroyElement` | 24 | `focusIn`/`focusOut` | 6 + 4 |
| `setProperties(` | 21 | `toggleProperty`, `scheduleOnce`, `@on("...")` | 5 each |
| `this.get(` | 19 | `elementId` | 4 |
| `classNameBindings` | 17 | `sendAction`, `.extend(` | 3 each |
| `click(` element handler | 16 | `this.actions`, `notifyPropertyChange`, `didUpdate`, `rerender()`, `this.send` | 2 each |
| `classNames` | 16 | `layoutName`, `didUpdateAttrs` | 1 each |

Absent entirely: `@discourseComputed`, computed macros (`@alias`, `@or`, ...), `this.attrs`,
`positionalParams`, `this.$()`, `didRender`, `willRender`, `ariaRole`. The autofixers
already removed those; the skill can mention them in one line each. Implicit injections
(`lib/implicit-injections.js`: `appEvents`, `store`, `site`, `session`, `messageBus`,
`siteSettings`, `keyValueStore`, `capabilities`, `currentUser`, tracking-state services)
exist only on `@ember/component`; a few classic components read them without `@service`,
and the script reports those reads.

Call-site side: 198 `(mut ...)` usages (almost all `@onChange={{fn (mut this.x)}}` into
select-kit), 125 `<Input>` (~85 of them two-way `@value=`), 20 `<Textarea>`, 6 leftover
`(action ...)`.

## 4. What the git history teaches (325 "glimmer" commits)

Representative conversions and the lesson each carries (shas are cited inline in
`references/feature-mapping.md` and `references/pitfalls.md`):

- `9874801f946` topic-post-badges: smallest mechanical conversion; wrapper `<span>` from
  `tagName` + `classNameBindings`.
- `2a52f7f13f6` track-selected: the observer *was* the component; became an `{{on}}`.
- `dd329d55a52` topic-status: 100 lines of side-effecting computeds became template
  `{{#if}}`s. Follow-ups `323013d9c79` (`this.topic` left in `@outletArgs`), `248501f4c7d`
  (missing `.` when inlining i18n keys), `94b309b05e0` (`unless` → `if/else`).
- `b1b218aa992` choose-topic: two-way `@selectedTopicId` → `@topicChangedCallback`,
  three call sites incl. a plugin.
- `c18e5d1698c` security-key-form: child `this.set`s three args → three setter args
  `@setShowSecurityKey={{fn (mut @showSecurityKey)}}`.
- `62c8904721a` ace-editor: 4 observers → `{{didUpdate}}` + custom `modifier()`;
  two-way `@content` → `@onChange` at 5 sites.
- `f3c6260e1b3` inline-edit-checkbox: `didReceiveAttrs` reset → `@resettableTracked`.
- `4e417223e5d` simple-list: `didReceiveAttrs` → `@cached` getter returning a tracked array.
- `ccc895fdf09` tag-info: `didInsertElement`+`didUpdateAttrs` → `helperFn` effect; its classic
  consumers later needed the `@trackedArray` bridge added in `11fac4c6bca`.
- `3f7cf1139da` reviewable item: per-arg state reset → `@cached get state()` keyed on the
  arg; `{{fn (mut ...)}}` → `@onClaim` callback.
- `991cbda4528` topic-navigation: `classNameBindings` → `dConcatClass`; observer →
  `TrackedMediaQuery` getter; `canRender`+`didUpdateAttrs` hack → `{{#each (array @topic)
  key="id"}}`; two-way `expanded` → `@onExpandToggle`; fixed a latent bug (same-or-less code).
- `db90d22869f` mobile-nav: `@tagName("ul")` → `<ul>`; jQuery window click →
  `dCloseOnClickOutside`.
- `3a945f3663c` + `cddc96e9c01` create-topic-button: **class field silently overridable by
  an arg in classic; not in Glimmer** (`label = "topic.create"` → `this.args.label ??
  "topic.create"`). The canonical regression.
- `39e1b97a5d1`: `@action` inside an `actions: {}` hash is a silent no-op.
- `92312eec7b1`: a `.gjs` file still extending `@ember/component` had non-reactive args.
- `4acd9c67535`: half-converted reactivity chains (classic macro on a model reading a
  tracked array) break silently.
- `a88902950af` DButton (2022): `attributeBindings` → explicit attributes, string
  `@action` deprecation; subclasses (`DButton.extend`) → composition.
- `3bfd8c7192a` user-field: `layoutName` → component map + `<this.component />`.
- `7b062e24def` load-more: `element` helper for optional wrapper, 25+ call sites.

Reverts: `261ef8404ee`→`5d568d0bab1`→`0548f242081` (build tooling), `27408c7e14b`→
`9408ea44617` (discourse-root, same day), `707a91243c3`→`f8d61a341e0` (outletArgs re-render).
Lesson: run the acceptance/system tests that touch the page, not just the unit test.

## 4b. What the Ember docs and RFCs teach

Sources: Ember guides v5.12 "upgrading/current-edition" (the release guides now redirect
to a stub), the Octane-vs-classic cheat sheet, RFC 0311/0415/0416/0410/0566/0478/1006/1068,
the `@ember/render-modifiers` and `ember-modifier` READMEs, deprecations.emberjs.com, and
RFC 1216 "Deprecate Classic Ember Component" (emberjs/rfcs#1216, opened 2026-07-27, merged
2026-08-31, `until: 8.0`).

- **Glimmer component surface is tiny**: `constructor(owner, args)`, `willDestroy()`,
  `args`, `isDestroying`, `isDestroyed`. `args` is frozen in dev; writes are silent no-ops
  in prod. Class fields initialize after `super`, so they may read `this.args`.
- **Timing**: `constructor` runs before children and before modifiers install.
  `willDestroy` runs after child `willDestroy`s, after modifier destructors, and "after the
  DOM has been fully removed and is inaccessible". Element teardown therefore belongs in a
  modifier cleanup, not in `willDestroy`.
- **Two-way binding is the interface change**: "Glimmer components' `this.args` is
  read-only: the owner of the state changes it, and the child asks via a callback." RFC
  1216 calls it "the only step that changes the component's public interface -- review
  carefully".
- **Leaves first** (RFC 1216). The RFC's stated reason is that computed properties cannot
  depend on native getters. Verified against ember-source 6.10: `@computed` *can* depend on
  `@tracked` fields (same tag), and a parent never reads a child's getters, so the real
  constraint is a classic consumer whose dependent-key chain crosses a native getter on a
  converted class (a model, a service, a yielded object). Convert those consumers together
  or bridge with `@dependentKeyCompat`; base classes go with their subclasses.
- **Observers first**. The RFC says observers do not fire for `@tracked` updates. In
  Discourse they do: `config/environment.js` sets `_DEFAULT_ASYNC_OBSERVERS: true`, and
  async observers are driven by tag validation. The reason to remove them first is that
  `@observes` cannot live on a Glimmer class and a half-converted file gets stale,
  runloop-delayed double updates.
- **`{{on}}` differs from `{{action}}`**: no implicit `preventDefault`, no `this` binding,
  no `value="target.value"`; extra params need `(fn ...)`.
- **Render modifiers**: `did-insert` runs once per element insertion, never on rerender;
  `did-update` never on first render and only when the args passed *to the modifier*
  change. README: "we strongly encourage you to avoid these modifiers in new code" and
  "still generally an anti-pattern". Custom `modifier()` autotracks whatever it reads and
  re-runs with cleanup, replacing all three at once. Modifier args are lazy: an arg not
  read inside the body does not trigger re-runs.
- **Backtracking assertion**: writing tracked state that was already read in the same
  render throws ("You attempted to update `x` on `y`, but it had already been used
  previously in the same computation"). Getters must not write; modifiers that write
  tracked state read by the same template must defer.
- **Local override with fallback** is the documented shape for divergent local state:
  `@tracked local; get value() { return this.local ?? this.args.value; }`. Copying args in
  the constructor is explicitly wrong (runs once). Resetting on arg change has no
  first-class API; the docs say lift the state to the parent, else key the subtree.
- **`@cached`** only for expensive getters or where referential identity matters; it adds
  overhead and "may rerun even if the values themselves have not changed".
- **Dot-access reads of plain model fields do not track.** In ember-source `_getProp`
  consumes the property tag only for `get()` and template paths; a plain `obj.prop` read
  inside a getter, modifier, or `helperFn` consumes nothing, whatever the base class
  (`EmberObject`, `RestModel`, POJO), while `@tracked` fields and `@computed` getters on
  the model do consume tags on dot access. `set()` still dirties the tag. A converted getter
  must read a plain field with `get()`, or the model field must become `@tracked`.
  `@dependentKeyCompat` does not help here; it bridges the opposite direction (a classic
  consumer watching a native getter). This is why the lint config keeps `ember/no-get` off.
- **Modifier bodies autotrack every read** and re-run after cleanup; a mount-once hook
  moved verbatim into one `modifier()` re-runs on every change of anything it read. One
  modifier per concern; one-shot values are captured outside or read under `untrack`
  (`@glimmer/validator`, already used by `ui-kit/d-decorated-html.gjs`).
- **Built-ins**: `<Input @value>` / `<Textarea @value>` / `@checked` remain two-way by
  design; for one-way use native `<input value={{x}} {{on "input" ...}}>`. Forwarding an
  arg into one of them (`<Input @value={{@foo}}>`) writes through the reference to the
  caller's property, which hides a two-way binding inside a Glimmer component.
- **Helpers**: `mut` docs say "Don't use `mut`"; `readonly` is vestigial and only
  meaningful for classic children; `{{action}}`/`(action)` were removed from Ember and
  survive here only through the shim in `lib/ember-events.js` and `helpers/action.js`,
  which logs a deprecation; `hasBlock` → `(has-block)`; `elementId` → `dUniqueId`/`guidFor`.
  A classic handler returning `false` got both `preventDefault()` and `stopPropagation()`
  from `lib/ember-events.js`; `{{on}}` does neither.
- **Arrays**: prototype extensions deprecated (5.10); `trackedArray()` from
  `@ember/reactive/collections` (RFC 1068) is the current API; re-setting
  `this.items = this.items` is now called an anti-pattern (RFC 0812).

## 5. Discourse-specific building blocks the skill should point to

| Need | Use | Not |
|---|---|---|
| element reference / DOM setup+teardown | `modifier()` from `ember-modifier` as a class field, returns cleanup | `{{didInsert}}`/`{{willDestroy}}` from `@ember/render-modifiers` (anti-pattern per lint comment; 177 legacy uses) |
| autotracked effect with cleanup, no element | `helperFn` (`discourse/helpers/helper-fn`) invoked as `{{this.effect}}` | observers |
| re-run on a specific arg change, DOM-bound | `modifier()` reading the arg inside its body (autotracks) | `{{didUpdate fn @arg}}` (re-runs only when the args passed to the modifier itself change) |
| reset local state when an arg changes | `@resettableTracked` (`discourse/lib/tracked-tools`), or `@cached` getter keyed on the arg | `didReceiveAttrs` |
| tear the subtree down when an identity changes | `{{#each (array @model) key="id"}}` | `canRender` toggles + `next()` |
| stable callback identity for `on`/`off` pairs | `@bind` (`discourse/lib/decorators`) | `@action` (also fine) / inline arrows |
| after-render DOM work with destroy guard | `@afterRender` decorator or `schedule("afterRender")` + `isDestroying` check | `scheduleOnce` on `this` |
| media-query / resize driven state | `TrackedMediaQuery`, `dOnResize` modifier | `matchMedia` listeners in `didInsertElement` |
| click-outside | `dCloseOnClickOutside` modifier | jQuery `$(window).on("click.ns")` |
| dynamic wrapper tag | `dElement` (`discourse/ui-kit/helpers/d-element`) | `@tagName` arg forwarding |
| class concatenation | `dConcatClass` | string concat helpers |
| class-level non-DOM cleanup | `willDestroy()` with `super.willDestroy(...arguments)`, or `registerDestructor(this, ...)` | `willDestroyElement` |
| async continuation guard | `this.isDestroying || this.isDestroyed` | `!this.element` checks |
| tracked collections | `trackedArray()/trackedObject()` from `@ember/reactive/collections` | `TrackedArray` from `@ember-compat/tracked-built-ins` (autofixed away) |
| native input two-way | `<input value={{...}} {{on "input" (withEventValue ...)}}>` | `<Input @value>` when the value is an arg |
| html strings | `trustHTML` from `@ember/template` | `htmlSafe` |

Lint autofixers that do part of the job: `discourse/no-computed-macros`,
`discourse/no-discourse-computed`, `discourse/ui-kit-imports`,
`discourse/migrate-tracked-built-ins-to-ember-collections`, `discourse/deprecated-imports`,
`discourse/no-at-class`. Lint rules that will fire on the result and must be satisfied:
`ember/no-classic-components`, `ember/no-observers`, `ember/require-tagless-components`,
`ember/no-actions-hash`, `ember/no-on-calls-in-components`,
`ember/no-empty-glimmer-component-classes`, `sort-class-members` bucket order
(services → tracked → properties → private → constructor → willDestroy → rest → template),
`discourse/no-unnecessary-tracked` (warn).

## 6. Consumers that can break

- **Call sites in core and bundled plugins**: grep for `<ComponentName` and for the import
  path. Also `{{component "name"}}` / `<this.dynamicComponent>` string lookups.
- **External plugins/themes** (`~/discourse/all-the/all-the-{plugins,themes}/{official,third-party}`,
  `all-the-custom-{plugins,themes}`): 282 distinct core component imports. Classic
  components with external importers include `basic-topic-list` (16), `d-editor` (12),
  `select-kit/select-kit-row` (7), `preference-checkbox` (7), `d-textarea`, `d-radio-button`,
  `d-navigation`, `value-list`, `user-profile-avatar`, `global-notice`, `category-unread`,
  `categories-boxes`, `admin-nav`. External **subclasses** are concentrated in select-kit
  (`ComboBoxComponent` 12, `DropdownSelectBoxComponent` 8, `SelectKitRowComponent` 5,
  `MultiSelectComponent` 5) and `UserCardContents` (3).
- **`api.modifyClass("component:...")`**: 1 in bundled plugins (`search-result-entry`), 22
  in external plugins (`composer-body` ×3, `tag-drop`, `d-editor` ×2, `topic-title`,
  `topic-progress`, `topic-footer-buttons`, `composer-editor`, `composer-actions`,
  `composer-action-title`, `d-navigation`, `admin-theme-editor`, ...), 18 in external
  themes (`d-navigation` ×2, `topic-timer-info`, `directory-item`, `search-result-entry`,
  `d-editor`, ...). A conversion changes the prototype these patch (`this.foo` →
  `this.args.foo`, hooks gone), so the skill must detect and flag these. The file name and
  resolver path must not change.
- **Plugin outlets**: `@outletArgs={{lazyHash topic=this.topic}}` must become `@topic`;
  connectors that were classic get an explicit wrapper element.
- **Tests**: integration tests using `this.set(...)`, `hbs`, or asserting on the wrapper
  element's classes; acceptance tests asserting on markup that changes when `DButton`
  replaces `<a onclick>`.

## 7. Decisions

### 7.1 Scope of a conversion

One component per change by default, plus its in-tree subclasses if it is a base class,
plus a classic consumer when the reactivity-chain rule requires converting it together,
plus call-site edits; several requested components become separate commits, leaves first. Select-kit base classes are explicitly out of scope for this skill: they are a
framework of their own with external subclasses; flag and stop.

### 7.2 What "minimal viable" means concretely

- Keep names, file paths, arg names, yielded values, DOM structure, CSS classes, and ids.
- Do not drop jQuery, change markup to ui-kit primitives, or rename `_private` members
  unless it falls out of the conversion at zero extra cost.
- Do not "fix" behavior that the old code had, even when it looks wrong, unless the fix is
  same-or-less code; note it in the report either way.
- The frontend-conventions skill applies only to added/changed lines (its Step 0 rule).

### 7.3 Procedure

The procedures that follow from these decisions (two-way bindings, lifecycle, wrapper, order
of work) are SKILL.md's steps and the references; this document does not restate them.

## 8. Decisions on the open questions

- **External (non-bundled) plugin/theme call sites** are never edited in the conversion
  change. The report lists each file with the exact edit; the user decides whether the
  conversion waits for those repos. `scripts/analyze.sh` scans the `all-the-*` checkouts
  in one pass (about ten seconds per component).
- **`{{fn (mut this.x)}}` at call sites** is acceptable for minimal changes when the caller
  is classic or a template with no backing class. A Glimmer caller passes an `@action`
  that assigns a `@tracked` field, adding one if none exists; a Glimmer component that only
  relays the arg forwards the setter unchanged. `(fn (mut @x))` inside the converted
  component is not allowed (it re-creates the hidden binding).
- **`@ember/render-modifiers`** are not added by conversions, even for one-shot
  `didInsert`; always `modifier()` from `ember-modifier`. Existing uses elsewhere are left
  alone.
- **`modifyClass` patches**: a patch in a bundled plugin is in-tree and is updated in the
  same change; a patch in an external checkout is flagged. The file path and resolver name
  never change.
- **Empty class after conversion**: emit a template-only component (CLAUDE.md forbids empty
  backing classes and `ember/no-empty-glimmer-component-classes` is an error), unless an
  external `extends`/`modifyClass` consumer needs the class, in which case keep it with a
  targeted lint disable and report the consumer.
- **Out-of-tree components** (external plugins and themes) follow the same procedure; the
  script detects the target repo, derives the plugin import path, and scans the target
  repo plus core (`CORE_DIR`).
