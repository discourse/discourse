# Feature mapping: classic → Glimmer

Every classic component feature and its replacement. Snippets with a sha in parentheses
are lifted or adapted from real conversions in this repo (`git show <sha>` for the whole
diff); the rest are illustrative sketches, not landed diffs. Attribute, argument, and modifier order on the
elements below follows `discourse-frontend-conventions` Step 4 (attributes, then
`@arguments`, then modifiers).
Frequency counts are from the 188 components still classic when this was written, so the
top rows matter most.

## Imports

| Classic | Glimmer |
|---|---|
| `import Component from "@ember/component";` | `import Component from "@glimmer/component";` |
| `import { tagName, classNames, classNameBindings, attributeBindings } from "@ember-decorators/component";` | delete |
| `import { observes, on } from "@ember-decorators/object";` | delete |
| `import { computed, set, get } from "@ember/object";` | `import { action } from "@ember/object";` only; `set`/`get` stay only for untracked `EmberObject` boundaries |
| `import { alias, or, ... } from "@ember/object/computed";` / `discourse/lib/decorators` macros | delete (autofixed by `discourse/no-computed-macros`) |
| `import discourseComputed from "discourse/lib/decorators";` | delete (autofixed by `discourse/no-discourse-computed`) |
| `import { tracked } from "@glimmer/tracking";` | add; `cached` from the same module when needed |
| `import { modifier } from "ember-modifier";` | add when a lifecycle hook touched the DOM |
| `import { on } from "@ember/modifier";`, `import { fn } from "@ember/helper";` | add for element handlers |
| `import { untrack } from "@glimmer/validator";` | add for one-shot reads inside a mount-once modifier |
| anything else a replacement below needs | see the import list at the top of SKILL.md |
| `/* eslint-disable ember/no-classic-components, ember/no-observers, ember/require-tagless-components */` | delete the whole banner |

Autofixers that do part of this for you, so run `bin/lint --fix` on the file first:
`discourse/no-computed-macros`, `discourse/no-discourse-computed`, `discourse/ui-kit-imports`,
`discourse/migrate-tracked-built-ins-to-ember-collections`, `discourse/deprecated-imports`,
`discourse/no-at-class`.

## Wrapper element (163 files use `tagName`, 16 `classNames`, 17 `classNameBindings`, 10 `attributeBindings`, 4 `elementId`)

```js
// adapted from 9874801f946 (topic-post-badges; the commit used object syntax and left out
// ...attributes, which golden rule 4 requires)
@tagName("span")
@classNameBindings(":topic-post-badges")
export default class TopicPostBadges extends Component {
  <template>{{~#if this.displayUnreadPosts~}} ... {{~/if~}}</template>
}
// after
export default class TopicPostBadges extends Component {
  <template>
    <span class="topic-post-badges" ...attributes>{{~#if this.displayUnreadPosts~}} ... {{~/if~}}</span>
  </template>
}
```

```js
// before (991cbda4528, topic-navigation)
@classNameBindings(
  "info.topicProgressExpanded:topic-progress-expanded",
  "info.renderTimeline:with-timeline",
  "info.withTopicProgress:with-topic-progress"
)
// after
<div
  class={{dConcatClass
    (if this.info.topicProgressExpanded "topic-progress-expanded")
    (if this.info.renderTimeline "with-timeline")
    (if this.info.withTopicProgress "with-topic-progress")
  }}
  ...attributes
>
```

```js
// before (a88902950af, d-button)
tagName: "button",
classNameBindings: ["isLoading:is-loading", "btnLink::btn", "noText", "btnType"],
attributeBindings: ["form", "isDisabled:disabled", "computedTitle:title", "tabindex", "type"],
// after
<button
  class={{dConcatClass (if @isLoading "is-loading") (unless @btnLink "btn") ...}}
  form={{@form}}
  tabindex={{@tabindex}}
  type={{or @type "button"}}
  ...attributes
  disabled={{this.isDisabled}}
  title={{this.computedTitle}}
>
```

Binding syntax: `"flag:on"` → `(if this.flag "on")`; `"flag:on:off"` → `(if this.flag "on"
"off")`; `"flag::off"` → `(unless this.flag "off")`; `":static"` → literal. A bare `"name"`
depends on the value's type: `true` adds the dasherized property name (`(if this.isActive
"is-active")`), a string or number adds the value itself (`"btnType"` holding `"btn-primary"`
→ `this.btnType` inside `dConcatClass`), anything else adds nothing. Check the property's
type and the CSS before choosing.
`attributeBindings` of `"prop:attr"` → `attr={{this.prop}}`; bare `"role"` → `role={{this.role}}`
(and if `role` was a class field, `role="button"`). `elementId = "x"` → `id="x"`;
`this.set("elementId", ...)` in `init` → `id={{this.id}}` with a getter.

Splat placement (before the splat the caller wins, after it the component wins, `class`
merges) is `discourse-frontend-conventions` Step 4. A component with `@tagName("")` already
renders a fragment; keep it that way.

Dynamic tag from the caller (`@tagName` passed at call sites):

```js
// category-unread.gjs (still classic, but the pattern is right)
import dElement from "discourse/ui-kit/helpers/d-element";
{{#let (dElement (or @tagName "span")) as |TagName|}}
  <TagName class="category__badges" ...attributes>...</TagName>
{{/let}}
// or in JS: get wrapper() { return dElement(this.args.tagName ?? "div"); } then <this.wrapper>
```

Do not add `dElement` when the call sites all pass the same tag or none; fix the tag.

## Element event methods (16 `click(`, 7 `keyDown(`, 6 `focusIn`, 4 `focusOut`)

```js
// before (0c1a658f28c, html-with-links; now frontend/discourse/app/ui-kit/d-html-with-links.gjs)
click(event) { ... }
// after
@action
click(event) { ... }
<template>
  {{! eslint-disable ember/template-no-invalid-interactive }}
  <div ...attributes {{on "click" this.click}}>...</div>
</template>
```

The directive is a mustache comment inside `<template>`, placed above the element; it
disables the rule from there to the end of the template. The old
`template-lint-disable` form is itself a lint error in core now; rewrite any you find. An
external repo that still runs ember-template-lint (it has a `.template-lintrc.*`) takes
`{{! template-lint-disable no-invalid-interactive }}` instead.

Method → DOM event: `click`→`click`, `doubleClick`→`dblclick`, `keyDown`→`keydown`,
`keyUp`→`keyup`, `keyPress`→`keypress`, `mouseEnter`→`mouseenter`, `mouseLeave`→`mouseleave`,
`mouseMove`→`mousemove`, `mouseDown`→`mousedown`, `mouseUp`→`mouseup`, `focusIn`→`focusin`,
`focusOut`→`focusout`, `change`→`change`, `input`→`input`, `submit`→`submit`,
`dragOver`→`dragover`, `dragStart`→`dragstart`, `drop`→`drop`, `touchStart`→`touchstart`,
`touchEnd`→`touchend`, `paste`→`paste`, `scroll`→`scroll`.

Classic handlers caught bubbled events from every descendant, so the wrapper is the target
unless the body already narrows with `event.target.closest(...)`. A classic handler that
returned `false` got `preventDefault()` and `stopPropagation()` (see
`lib/ember-events.js`), and `{{action}}` called `preventDefault()`; `{{on}}` does neither,
so add the calls the old behavior depended on. `{{on}}` also does not bind `this` (pass an
`@action`/`@bind` method) and has no `value="target.value"` option; use `withEventValue`
(data-flow reference, section 5).

## Args (every `this.x` not declared on the class)

```js
// before
{{#if this.closeAction}} <DButton @action={{this.closeAction}} /> {{/if}}
// after
{{#if @closeAction}} <DButton @action={{@closeAction}} /> {{/if}}
// in JS: this.args.closeAction
```

Before adding a `?? DEFAULT` getter, check whether the default is observably different
from `undefined` at every read site. `selectableUserBadges = null` (`badge-title`) was read
only through `(badges || [])` and select-kit's `makeArray`, both of which treat `null` and
`undefined` alike, so `this.args.selectableUserBadges` alone was faithful and the getter
would have been noise. Add the getter when the default is a real value, when a consumer
distinguishes the two (`in`, `hasOwnProperty`, `=== null`, a `??` of its own), or when
callers exist that do not pass the arg.

Class field defaults that callers override:

```js
// before (3a945f3663c → cddc96e9c01, create-topic-button)
label = "topic.create";          // callers passed @label and it won
// after
get label() { return this.args.label ?? "topic.create"; }
```

Positional params, `this.attrs`, `{{foo-bar x}}` curly invocation: none remain in this repo;
if met, convert to named args and angle brackets first.

## State (92 `@computed`, 63 `this.set(`, 21 `setProperties`, 19 `this.get(`, 5 `toggleProperty`)

```js
// before
_isSaved = false;
this.setProperties({ _isSaved: false, _isSaving: true });
this.toggleProperty("expanded");
// after
@tracked _isSaved = false;      // @tracked when the template, a getter it reads, a modifier, or a helperFn must react (SKILL.md Step 2.3)
this._isSaved = false; this._isSaving = true;
this.expanded = !this.expanded;
```

```js
// before
@computed("category", "categories", "noSubcategories")
get categoryBreadcrumbs() { ... }
// after
get categoryBreadcrumbs() { ... }               // reads this.args.category etc.; @cached per SKILL.md Step 2.2
```

Getter/setter pairs on a `@computed` (`get watchForLink()` / `set watchForLink(v)`) become
a plain accessor pair; the setter usually writes into an arg's object
(`this.args.composer.set(...)`) or a local tracked field.

`this.get("a.b")` on own state → `this.a?.b` (the old `get` was null-safe on the path).
`this.get("composer.titleLength")` → `this.args.composer?.titleLength` works because
`titleLength` is a `@computed` getter on the model. Reads of a *plain* model field inside a
getter, modifier, or `helperFn` are different: autotracking only sees reads that consume a
tag, and `model.x` does so only when the model declares `x` as `@tracked`/`@trackedArray`
or as a `@computed` getter. A plain field on an `EmberObject`, `RestModel`, or POJO is not
tracked even though `set()` dirties it, so a getter over it goes stale; template paths
(`{{@composer.title}}`) do track plain fields because they read through Ember's `getProp`.
When `@computed("composer.title")` becomes a getter, declare `title` `@tracked` on the
model (the `Reviewable` pattern in `3f7cf1139da`; classic `set()` writers keep working) or
read with `get(this.args.composer, "title")` when the model cannot change. Check the model
before assuming the getter updates. This is why `ember/no-get` stays off in the lint config.

`notifyPropertyChange("x")` → nothing when `x` is tracked; when it existed to poke a
classic consumer of a model, the model needs `@tracked`/`@trackedArray` (`tag-info.gjs`,
`controllers/user-activity/bookmarks.js` in `11fac4c6bca`), or the getter needs
`@dependentKeyCompat` (`services/presence.js`, `ecdf199585a`).

`this.rerender()` → change the tracked state that should drive the rerender; for a forced
subtree rebuild, `{{#each (array this.key) key="@identity"}}`.

Arrays: `pushObject`/`removeObject`/`arrayContentDidChange` (prototype extensions,
deprecated since Ember 5.10) → `trackedArray()` from `@ember/reactive/collections` with
native `push`/`splice` (`4e417223e5d` builds one inside a `@cached` getter), or reassign a
genuinely new array to a `@tracked` field. Do not re-assign the same array to itself
(`this.items = this.items`) to force an update; that is the RFC 0812 anti-pattern. Tracked
collections are created with factory calls, not `new`; `new TrackedArray` from
`@ember-compat/tracked-built-ins` is retired and autofixed away.

## Observers (13 files)

Pick by intent:

```js
// 1. derived state → getter (topic-navigation, 991cbda4528)
@observes("info.topicProgressExpanded") _expanded() { ...set flags... }
// after: get renderTimeline() { ... }  reading TrackedMediaQuery + tracked flags

// 2. DOM side effect on arg change → modifier reading the arg (ace-editor, 62c8904721a)
@observes("content") contentChanged() { this._editor.getSession().setValue(this.content); }
// after:
setContent = modifier(() => {
  const content = this.args.content || "";
  if (content === this.editor.getSession().getValue()) { return; }
  this.skipChangePropagation = true;
  this.editor.getSession().setValue(content);
  this.skipChangePropagation = false;
});
// <div class="ace" ...attributes {{this.setContent}}>
// The same file still uses {{didInsert}}/{{didUpdate}} from @ember/render-modifiers for its
// other observers; that is legacy (golden rule 3), fold each into a modifier() that reads the arg.

// 3. non-DOM side effect with cleanup → helperFn (user-tip.gjs)
registerTip = helperFn((_, on) => {
  const tip = { id: this.args.id, priority: this.args.priority ?? 0 };
  this.userTips.addAvailableTip(tip);
  on.cleanup(() => this.userTips.removeAvailableTip(tip));
});
// {{this.registerTip}} in the template; re-runs (after cleanup) whenever a read tracked value changes

// 4. the observer only reacted to user input → event handler (track-selected, 2a52f7f13f6)
@observes("selected") ... → {{on "input" this.onChange}}
```

Observers with `discourseDebounce(this, fn, ms)` keep the debounce inside the replacement.
Observers that wrote `this.set("autoPosted", false)` on an arg change are the "reset local
state" case: `@resettableTracked`. A replacement that writes tracked or model state
(`this.args.composer.set("featuredLink", null)`) runs during render when it is a getter,
modifier, or `helperFn`, so the write must be deferred (`schedule("afterRender")`, `next`,
or the debounce the observer already had) or it trips the backtracking-rerender assertion.

## Lifecycle (26 `init`, 34 `didInsertElement`, 25 `this.element`, 24 `willDestroyElement`, 11 `didReceiveAttrs`, 3 `didUpdateAttrs`/`didUpdate`, 5 `@on(`)

```js
// init → constructor
init() { super.init(...arguments); this.set("_selectedId", this._find(...)); }
// after
@tracked _selectedId;
constructor() { super(...arguments); this._selectedId = this.#find(...); }
// or a field initializer: @tracked _selectedId = this.#find(this.args.badges);
```

Use a field initializer when the value is a one-line expression. Use a `constructor` when
the old `init` had intermediate locals or the expression wraps across lines: prettier
pushes a wrapped initializer's `@tracked` onto its own line, and keeping the original
statements makes the diff read as a faithful port (`badge-title`).

```js
// didInsertElement + willDestroyElement + this.element → one modifier per concern
// (illustrative, adapted from the still-classic composer-title; not a landed conversion)
didInsertElement() {
  super.didInsertElement(...arguments);
  const input = this.element.querySelector("input");
  this._focusHandler = () => this.set("isTitleFocused", true);
  this._blurHandler = () => this.set("isTitleFocused", false);
  input.addEventListener("focus", this._focusHandler);
  input.addEventListener("blur", this._blurHandler);
  if (this.focusTarget === "title") { putCursorAtEnd(input); }
  if (this.get("composer.titleLength") > 0) { discourseDebounce(this, this._titleChanged, 10); }
}
willDestroyElement() { ...removeEventListener for both... }
// after
trackFocus = modifier((element) => {
  const input = element.querySelector("input");
  const onFocus = () => (this.isTitleFocused = true);
  const onBlur = () => (this.isTitleFocused = false);
  input.addEventListener("focus", onFocus);
  input.addEventListener("blur", onBlur);
  if (untrack(() => this.args.focusTarget === "title")) { putCursorAtEnd(input); }
  return () => {
    input.removeEventListener("focus", onFocus);
    input.removeEventListener("blur", onBlur);
  };
});
// <div class="title-input" ...attributes {{this.trackFocus}}>
```

`focusTarget` comes from a getter on the composer service that changes while the title is
mounted; read without `untrack` (from `@glimmer/validator`), the modifier would re-run on
each change and `putCursorAtEnd` would steal focus. The alternatives are an instance flag
(`ui-kit/modifiers/d-auto-focus.js` and its `didFocus`) or a snapshot into a plain field in
the constructor. The old hook's `if (composer.titleLength > 0) discourseDebounce(this,
this._titleChanged, 10)` is not a mount concern: it is the first run of the `_titleChanged`
effect (Observers case 3), so it drops out of the modifier.
When later code needs the element (`_checkForUrl` calling `this.element.querySelector`),
store it from the modifier on a plain field (`this.element = element`; not tracked unless
rendered) and clear it in the cleanup.

```js
// appEvents in didInsertElement/willDestroyElement → constructor/willDestroy (ace-editor)
constructor() {
  super(...arguments);
  this.appEvents.on("ace:resize", this.resize);       // this.resize is @bind
}
willDestroy() {
  super.willDestroy(...arguments);
  this.appEvents.off("ace:resize", this.resize);
}
// registerDestructor(this, () => ...) from "@ember/destroyable" is the same thing without a method
```

`this, this.method` pairs in `appEvents.on(name, this, this.method)` become `this.method`
with `@bind` on the method so `off` gets the same reference.

```js
// didReceiveAttrs that reset local state → @resettableTracked (f3c6260e1b3, inline-edit-checkbox)
didReceiveAttrs() { super.didReceiveAttrs(...arguments); this.set("value", this.checked); }
// after
@resettableTracked value = this.args.checked;   // re-seeds whenever this.args.checked changes
```

```js
// didUpdateAttrs keyed reset → @cached getter keyed on the arg (3f7cf1139da, reviewable item)
@cached
get state() {
  void this.args.reviewable;                     // read it so the cache keys on it
  return trackedObject({ claimed: false, editing: false });
}
```

```js
// canRender + didUpdateAttrs + next() rebuild hack → keyed each (991cbda4528)
{{#each (array @topic) key="id"}}
  {{yield this.info}}
{{/each}}
```

`@on("init")` → constructor; `@on("didInsertElement")` → modifier; `@on("willDestroyElement")`
→ modifier cleanup or `willDestroy` (`8a09fd370a6`). `didRender`/`willRender`/`willUpdate`
are almost always compensating for two-way bindings or computed side effects; once those
are getters, delete the hook.

`schedule("afterRender", ...)` inside a hook: keep it inside the modifier when it needs the
DOM settled, or use `@afterRender` on a method (it already guards `isDestroying`). Replace
`!this.element || this.isDestroying || this.isDestroyed` guards in async callbacks with
`this.isDestroying || this.isDestroyed`.

Other things hooks commonly contain:

| In the hook | Replacement |
|---|---|
| `$(window).on("click.ns", ...)` / `document.addEventListener("click", ...)` to close on outside click | `{{dCloseOnClickOutside this.close}}` from `discourse/ui-kit/modifiers/d-close-on-click-outside` (`db90d22869f`, `991cbda4528`) |
| `matchMedia(...)` listeners, window resize handlers feeding state | `new TrackedMediaQuery(query)` (`discourse/lib/tracked-media-query`) read from a getter, torn down in `willDestroy` (`991cbda4528`); element size → `dOnResize` |
| `this.elementId` / `guidFor(this)` used to build ids | `dUniqueId` from `discourse/ui-kit/helpers/d-unique-id`, or a literal id |
| `htmlSafe(...)` | `trustHTML` from `@ember/template` (autofixed by `discourse/deprecated-imports`) |

## Actions (2 `this.actions`, 1 `this.send`, 3 `sendAction`)

```js
// actions hash → @action methods (41593a5d7d3)
actions = { toggleItem() { ... } };   // and <a href onclick={{action "toggleItem"}}>
// after
@action toggleItem(event) { event.preventDefault(); ... }   // and <a href {{on "click" this.toggleItem}}>
```

Keep the existing element. Swapping an `<a>` for `<DButton>` (as that commit did) is a
markup change that breaks selectors; do it only when asked (see pitfalls).

`this.send("foo")` → `this.foo()`. `sendAction("name")` → `this.args.name?.()`. A string
`@action="save"` at a call site must become a function reference. `this.send` that bubbled
to a route: pass the route action down as an arg.

## Mixins, `extend`, layout

```js
// mixin → composition (51a32de45ee, uppy-backup-uploader)
export default class X extends Component.extend(UppyUploadMixin) { id = "..."; type = "..."; }
// after
uppyUpload = new UppyUpload(getOwner(this), { id: "...", type: "...", uploadDone: (d) => this.args.done(d.file_name) });
```

`layoutName: fmt("field.field_type", "components/user-fields/%@")` → a map of imported
components and `<this.fieldComponent />` (`3bfd8c7192a`). `layout = hbs\`...\`` → a plain
`<template>` with a getter (`d6d3fc86294`). A classic `Component.extend({ ... })` object
body becomes class members.

## Decorators from `discourse/lib/decorators`

| Decorator | Glimmer | Note |
|---|---|---|
| `@bind` | keep | stable identity for `on`/`off`, listeners, modifiers |
| `@debounce(ms)` | keep | |
| `@afterRender` | keep | already guards destruction |
| `@observes` | remove | see Observers |
| `@on("...")` | remove | see Lifecycle |
| `@readOnly` | remove | plain getter |
| default `discourseComputed` | remove | autofixed |

## Template-level

| Classic | Glimmer |
|---|---|
| `{{this.x}}` for an arg | `{{@x}}` |
| `{{hasBlock}}` / `{{has-block}}` | `(has-block)` / `(has-block "name")` |
| `{{action "x"}}`, `(action "x")`, `onclick={{action ...}}` | `{{on "click" this.x}}`, `(fn this.x arg)`, `@action={{this.x}}` |
| `{{mut this.x}}` on own state | fine to keep with `@tracked x`; `(fn (mut this.x))` as a select-kit `@onChange` is idiomatic |
| `{{mut @x}}` / `(fn (mut @x))` | writes through to the caller: a hidden two-way binding, see data-flow |
| `{{readonly x}}` | drop; args are already one-way |
| `{{unbound x}}` | rare; keep only if the freeze was intentional |
| `<Input @value={{this.arg}}>` where `arg` is an arg | see data-flow |
| `{{component "name"}}` with a string | keep; the file path is unchanged |
| `{{yield}}`, `{{yield x}}`, named blocks | unchanged |
| `elementId` / `{{this.elementId}}` in the template | `dUniqueId` from `discourse/ui-kit/helpers/d-unique-id`, or a literal id |

## Reactivity boundary with classic code

- A classic parent's `@computed("childValue")` still works when the child calls back and
  the parent `set`s its own property; computed properties can depend on `@tracked` fields.
- A classic consumer whose dependent key crosses a *native getter* on a class you convert
  (a model, a service, a yielded object) stops updating; give that getter
  `@dependentKeyCompat` or convert the consumer.
- Reading a model property that classic code updates with `set()`: see the State section
  above (tracked only when the model declares it, else `get()`).
- `trackedArray`/`@trackedArray` content changes are bridged into `@computed` dependencies
  by core (`11fac4c6bca`), so classic consumers of a model you make tracked keep working.
