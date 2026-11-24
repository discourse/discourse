# Feature mapping: classic → Glimmer

Use the sections that match features in the component. For adaptation examples with a commit
ID, run `git show <sha>`. Follow the [frontend conventions](../../discourse-frontend-conventions/SKILL.md)
for attribute, argument, and modifier order.

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
| Implicit injection from `lib/implicit-injections.js` | declare `@service` |
| `/* eslint-disable ember/no-classic-components, ember/no-observers, ember/require-tagless-components */` | delete the whole banner |

The final lint pass can autofix some mechanical changes:
`discourse/no-computed-macros`, `discourse/no-discourse-computed`, `discourse/ui-kit-imports`,
`discourse/migrate-tracked-built-ins-to-ember-collections`, `discourse/deprecated-imports`,
`discourse/no-at-class`.

## Wrapper element

```js
// adapted from 9874801f946 (topic-post-badges)
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

Use `dConcatClass` from `discourse/ui-kit/helpers/d-concat-class` for class bindings.
Binding syntax: `"flag:on"` → `(if this.flag "on")`; `"flag:on:off"` → `(if this.flag "on"
"off")`; `"flag::off"` → `(unless this.flag "off")`; `":static"` → literal. A bare `"name"`
depends on the value's type: `true` adds the dasherized property name (`(if this.isActive
"is-active")`), a string or number adds the value itself (`"btnType"` holding `"btn-primary"`
→ `this.btnType` inside `dConcatClass`), anything else adds nothing. Check the property's
type and the CSS before choosing.
`attributeBindings` of `"prop:attr"` → `attr={{this.prop}}`; bare `"role"` → `role={{this.role}}`
(and if `role` was a class field, `role="button"`). `elementId = "x"` → `id="x"`;
`this.set("elementId", ...)` in `init` → `id={{this.id}}` with a getter.
A boolean bound to an `aria-*` attribute rendered as the string `"true"`/`"false"`; Glimmer
drops an attribute whose value is `false`, so write `aria-pressed={{if this.active "true"
"false"}}` (`DTapTile`). When unsure what the classic wrapper rendered, render it in a
scratch test that asserts its `innerHTML` against a wrong value (the failure prints the
markup), convert, and compare.

Keep an existing fragment's `...attributes`. Preserve significant template whitespace
(`{{~ ~}}`, `9874801f946`). Before changing a wrapper, check style and test selectors.
An anonymous wrapper can affect sibling and child-position selectors such as `:last-child`
even when it has no classes, as in `ReviewableField`.

Dynamic tag from the caller (`@tagName` passed at call sites):

```js
import dElement from "discourse/ui-kit/helpers/d-element";
get wrapper() {
  return dElement(this.args.tagName ?? "span");
}
// <this.wrapper class="category__badges" ...attributes>...</this.wrapper>
```

Use a static wrapper when all callers use the same effective tag. Remove their redundant
`@tagName` arguments. Keep `@tagName` as a named arg when callers select different elements.
An empty string selects the helper's pass-through wrapper. Keep it distinct from the
default tag when callers use it to select a fragment.

## Element event methods

```js
// before (0c1a658f28c, html-with-links; now frontend/discourse/app/ui-kit/d-html-with-links.gjs)
click(event) { ... }
// after
@action
click(event) { ... }
<template>
  {{! eslint-disable-next-line ember/template-no-invalid-interactive }}
  <div ...attributes {{on "click" this.click}}>...</div>
</template>
```

Use the next-line directive for a noninteractive wrapper that must keep a delegated
listener. In an external repo using ember-template-lint, use its corresponding directive.

Method → DOM event: `click`→`click`, `doubleClick`→`dblclick`, `keyDown`→`keydown`,
`keyUp`→`keyup`, `keyPress`→`keypress`, `mouseEnter`→`mouseenter`, `mouseLeave`→`mouseleave`,
`mouseMove`→`mousemove`, `mouseDown`→`mousedown`, `mouseUp`→`mouseup`, `focusIn`→`focusin`,
`focusOut`→`focusout`, `change`→`change`, `input`→`input`, `submit`→`submit`,
`dragOver`→`dragover`, `dragStart`→`dragstart`, `drop`→`drop`, `touchStart`→`touchstart`,
`touchEnd`→`touchend`, `paste`→`paste`, `scroll`→`scroll`.

A listener on the wrapper still receives bubbling events from descendants. Port any
`event.target.closest(...)` filter. In classic dispatch, returning `false` called
`preventDefault()` and `stopPropagation()` (`lib/ember-events.js`, `0c1a658f28c`).
Make either operation explicit where the old handler relied on it. Pass a bound method
(`@action` or `@bind`) and use [`withEventValue`](data-flow.md#5-built-in-inputs-inside-the-converted-component)
when replacing the action helper's `value` option.

## Args

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

Keep any observable distinction between an omitted, null, and false value. For example,
`plans?.toSorted(...)` still throws for `@plans={{false}}`, which the classic truthiness
guard in `PaymentOptions` accepted. Audit hook-created defaults as well (`c96dce29348`).

Classic classes have no Glimmer-style `this.args`. An optional read such as
`this.args?.allowImages` in `RagUploader` silently ignored the caller. Changing a file to
`.gjs` alone also leaves its args untracked (`92312eec7b1`). Replace positional params,
`this.attrs`, and curly component invocations with named args and angle brackets where found.

Verify that template `@name` reads are caller args. A blanket rewrite changed
`PaymentPlan`'s `this.planClick` to an unpassed `@planClick` (`3dd5c4039d3`).
`scripts/self-args.py` can flag some of these.

## State

```js
// before
_isSaved = false;
this.setProperties({ _isSaved: false, _isSaving: true });
this.toggleProperty("expanded");
// after
@tracked _isSaved = false;
this._isSaved = false; this._isSaving = true;
this.expanded = !this.expanded;
```

```js
// before
@computed("category", "categories", "noSubcategories")
get categoryBreadcrumbs() { ... }
// after
get categoryBreadcrumbs() { ... } // reads this.args.category and other dependencies
```

Use `@tracked` when a write must update the template or an effect it reads. Keep JSDoc
types on surviving JavaScript fields (#44656). Use `@cached` for expensive getters or
when their result needs stable identity and derive any replacement collection inside
the getter from the inputs that reset it.

An unused dependency key may point to a dropped positional read from the
`discourseComputed` migration. Check the older implementation before dropping it
(`a2e64d4b458`, `DiscourseLinkedText` lost its interpolation parameters).

Getter/setter pairs on a `@computed` (`get watchForLink()` / `set watchForLink(v)`) become
a plain accessor pair; the setter usually writes into an arg's object
(`this.args.composer.set(...)`) or a local tracked field.

`this.get("a.b")` on own state → `this.a?.b` (the old `get` was null-safe on the path).
`this.get("composer.titleLength")` → `this.args.composer?.titleLength` works because
`titleLength` is a `@computed` getter on the model. `composer.title` is a plain field, so a
getter reading it goes stale. Declare `title` `@tracked` on the model
(the `Reviewable` pattern in `3f7cf1139da`; classic `set()` writers keep working) or read
with `get(this.args.composer, "title")`. Template paths (`{{@composer.title}}`) do track
plain fields, because they read through Ember's `getProp`. This is why `ember/no-get` stays
off in the lint config.

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
collections are created with factory calls. Some deprecated array reads such as
`firstObject` still work through `app/array-shim.js`. Switching to `[0]` in this case
is a port, as in `GroupsFormInteractionFields`.

## Observers

Replace observers before changing the base class. Discourse's async observers can still
fire for tracked changes during a partial conversion. Getters also cover the initial
value when a service set it before an observer could attach, as with the restored notice
in `GlobalNotice`. For non-DOM effects, import `helperFn` from
`discourse/helpers/helper-fn`. Choose the replacement by intent:

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
// Use modifier() for reactive DOM work. Read each dependency in its body.

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

## Lifecycle

Use `@resettableTracked` from `discourse/lib/tracked-tools` for local state that reseeds
from an arg. Use `modifier()` from `ember-modifier` for DOM effects. Its arguments are lazy, and only
reads in the body add dependencies. The modifier cleans up before each rerun and on
teardown. Its teardown still has the detached node for listener removal, so avoid
layout reads or ancestor lookups there. Use `willDestroy` after modifier cleanup for
instance teardown. Inspect lifecycle decorators such as `@on("willDestroyElement")` as
well as method names (`8a09fd370a6`).

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
// didReceiveAttrs that re-derives only while the arg is set → @cached latch (#46801, ui-kit/d-future-date-input)
didReceiveAttrs() {
  super.didReceiveAttrs(...arguments);
  if (this.input) { this.setProperties({ selection: ..., _date: ..., _time: ... }); }
}
// after
class InputState {
  @tracked date = null;
  @tracked selection = null;
  @tracked time = null;
}

#state = new InputState();

@cached
get state() {
  if (this.args.input) {
    // eslint-disable-next-line ember/no-side-effects
    this.#state = this.#stateFromInput(this.args.input);
  }
  return this.#state;
}
// actions and <Input @value={{this.state.time}}> write this.state.x
```

The `if` is the contract: an empty arg keeps the state, so a picked "custom" keeps its
pickers open after the input is cleared. `@resettableTracked` re-seeds on every change,
empty included, and loses it. `#state` is untracked, so writing it in the getter cannot
dirty a tag the render has read; the lint disable follows `d-async-content.gts`. The state
is rebuilt when anything the derivation reads changes, not on every arg change as
`didReceiveAttrs` was.

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

## Actions

```js
// actions hash → @action methods (41593a5d7d3)
actions = { toggleItem() { ... } };   // and <a href onclick={{action "toggleItem"}}>
// after
@action toggleItem(event) { event.preventDefault(); ... }   // and <a href {{on "click" this.toggleItem}}>
```

Keep the existing element to preserve selectors (`eccfc946f16`). Move actions into
methods, since leaving `@action` inside an action hash silently drops the handler
(`39e1b97a5d1`). A local `this.send("foo")` becomes `this.foo()`. If it bubbled to the
route, pass the route action down as an arg. `sendAction("name")` becomes
`this.args.name?.()`. For strings and action helpers, see
[call-site replacements](data-flow.md#6-action-and-mut-leftovers-at-call-sites).

When replacing `this.set()` inside a callback argument, check when it ran. For example,
`.finally(this.set(...))` evaluated the write immediately in `WatchedWordForm`.

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

Keep branch exclusivity and string assembly when moving computations into the template.
`TopicStatus` lost punctuation in an i18n key (`248501f4c7d`) and rendered both branches
until it used `{{#if}}...{{else}}` (`94b309b05e0`).

## Reactivity boundary with classic code

- A classic parent's `@computed("childValue")` still works when the child calls back and
  the parent `set`s its own property; computed properties can depend on `@tracked` fields.
- A classic consumer whose dependent key crosses a *native getter* on a class you convert
  (a model, a service, a yielded object) stops updating; give that getter
  `@dependentKeyCompat` or convert the consumer (`4acd9c67535`, `11fac4c6bca`).
- Reading a model property that classic code updates with `set()`: see the State section
  above (tracked only when the model declares it, else `get()`).
- `trackedArray`/`@trackedArray` content changes are bridged into `@computed` dependencies
  by core (`11fac4c6bca`), so classic consumers of a model you make tracked keep working.
