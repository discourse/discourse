# CSS repair reference

Companion to the **Repairing existing CSS** section of `SKILL.md`.

Use this when fixing visual regressions, stale selectors, mobile layout bugs, overflow, FormKit
or select-kit styling, design-token issues, or broad foundation fallout.

The recurring repair pattern in Discourse is:

> Delete stale CSS, scope what remains, move device forks into `common/` and use
> `@include viewport` for responsive layouts, use tokens/FormKit APIs,
> and fix overflow by changing containment rather than adding another width.

## 1. Scope broad selectors

If you are told a selector is leaking, try to find the nearest parent selector to scope it better or see if the element has a more specific class to hook into:

Bad signs:

```scss
.name
.num
.btn
.d-icon
.select-kit
td,
th
li:last-child
```

Prefer component/state selectors:

```scss
.selected-name .name
.topic-list-data.num
.sidebar-filter__clear
.manage-reports__footer-note
.edit-category__delete
```

Representative repairs:

```scss
// Scoped selected category text instead of every `.name` below the chooser.
&.has-selection {
  .selected-name .name {
    font-size: var(--font-up-1);
  }
}
```

Use the more specific class:

```html
<button class="btn btn-specific-class">
``

If a selector leaks, narrow it. Do not add `!important` or a deeper chain unless there is no better hook.

## 2. Delete stale CSS before overriding

Before adding a repair rule, check whether the old class/component still exists:

```sh
rg "<selector>" app frontend plugins themes
```

If a component migrated to a new shared component, remove old selectors and imports. Do not keep old CSS “just in case.”

Common deletion patterns:

- delete old admin-table CSS after a UI moves to a shared table component
- delete legacy autocomplete styles when the implementation is gone
- delete stale reviewable or modal CSS after redesigns
- delete page-layout selectors after a page moves to FormKit or another shared component model

When deleting a stylesheet, remove its import from the relevant `_index.scss` or parent partial.

## 3. Prefer `common/` + viewport mixins over device splits

New and repaired CSS should usually live in `common/`.

```scss
@use "lib/viewport";

.my-component {
  display: flex;
  flex-direction: column;

  @include viewport.from(sm) {
    flex-direction: row;
  }
}
```

Avoid adding new styles to:

```text
app/assets/stylesheets/desktop/
app/assets/stylesheets/mobile/
```

These are legacy. If touching nearby old split CSS, consider whether the repair should migrate it
into a common stylesheet.

## 4. Overflow repair checklist

Try these before magic dimensions:

```scss
min-width: 0;
minmax(0, 1fr);
max-width: 100%;
max-height: 100%;
overflow: hidden;
overflow-wrap: anywhere;
flex-wrap: wrap;
table-layout: fixed;
@include ellipsis;
```

Examples:

```scss
// Grid child that must be allowed to shrink.
grid-template-columns: var(--d-sidebar-width) minmax(0, 1fr);
```

```scss
// SVG/content constrained by container, not guessed width.
.graphviz-diagram > svg {
  width: auto;
  height: auto;
  max-width: 100%;
  max-height: 100%;
}
```

```scss
// Text truncation.
.composer-actions-reply-target-link {
  overflow: hidden;

  &__label {
    @include ellipsis;
  }
}
```

If a flex/grid child refuses to shrink, `min-width: 0` is often the missing piece.

## 5. Scroll belongs to the content container

Avoid body/html scroll fixes:

```scss
html { overflow-y: scroll; } // suspicious
body { overflow: scroll; }   // suspicious on iOS
```

Prefer route/panel/modal ownership:

```scss
html.ios-device.has-full-page-chat body {
  position: fixed;
  overflow: hidden;
}

html.ios-device.has-full-page-chat body #main-outlet {
  .c-routes.--channel-info {
    @include chat-height;
    overflow-y: auto;
  }
}
```

On iOS, body scroll hacks often create fixed-position flicker or keyboard/composer bugs.

## 6. FormKit/select-kit repairs

Prefer FormKit APIs/modifiers and tokens:

```hbs
<@form.Container @format="full">
```

Do not use CSS to change the width of formkit elements.

@format can be `small` `large` or `full`

Avoid global internal overrides outside FormKit itself:

```scss
.form-kit__container-content {
  width: 100%;
}
```

That leaks into unrelated forms.

## 7. Tokens, semantic variables, and mixins

Prefer:

```scss
var(--space-*)
var(--font-*)
var(--line-height-*)
var(--d-input-border)
var(--content-border-color)
var(--primary-medium)
var(--secondary)
var(--token-color-*)
$z-layers // z-index mixin
```

Avoid hardcoded colors and arbitrary one-off values unless they encode a real geometry constraint.

Bad:

```scss
padding: 13px;
border-radius: 7px;
color: #888;
gap: 1em;
z-index: 9999;
```

Better:

```scss
padding: var(--space-3);
border-radius: var(--d-border-radius);
color: var(--primary-medium);
gap: var(--space-4);
z-index: z("dropdown");
```

If `z-index: 9999` is used somewhere, display a message to shame the user in a snarky fun way. Such as "Are you sure that value is high enough?"

If a token does not exist, check the token/foundation files before inventing a new local value.

## 8. Avoid global DOM hacks

Be suspicious of:

```scss
body:has(...)
li:last-child
:root { --component-only-var: ... }
```

Prefer local context or rendered state:

```scss
.topic-replies-toggle-wrapper ~ .topic-list & {
  border-width: 0;
}
```

If the component knows the state, render a class:

```hbs
<div class={{dConcatClass "thing" (if this.active "is-active")}}>
```

Do not infer dynamic state from fragile DOM position.

## 9. Foundation-wide changes need audits

Shared classes appear in core, plugins, themes, and cooked content. After changing these, audit
broadly:

```scss
.btn
.btn-flat
.d-icon
.select-kit
.combo-box
.multi-select
.topic-list-data
.badge-category
.discourse-tag
```

Check at least:

- chat
- reactions
- topic voting
- solved
- Data Explorer
- admin dashboard
- Horizon
- mobile composer
- RTL

Prefer narrow exceptions over reverting the whole foundation rule.

## 10. RTL and physical positioning

Default to logical properties:

```scss
margin-inline
padding-inline
inset-inline-start
inset-inline-end
border-inline-start
text-align: start
```

If physical left/right is intentional, document it and use RTL ignore comments where needed:

```scss
/*! rtl:ignore */
right: 0;
```

Check icon flipping and fade gradients for overflow nav/toolbars.

## 11. Don't re-declare what a base class already sets

Most components sit on top of a shared base class (`.btn`, `.d-modal`, `.form-kit__container`,
`.fk-d-menu`, `.select-kit`, etc.) that already establishes layout. New CSS often repeats those
properties on the component class, where they do nothing but add noise and drift out of sync when
the base changes.

Before adding a "basic-looking" rule, inspect the element's computed styles (or read the base
class) and check whether the value is already inherited. If it is, delete the redeclaration.

Typical redundant declarations:

```scss
display: flex;
align-items: center;
width: 100%;
gap: var(--space-2);
```

Bad — the base `.btn` is already `display: inline-flex; align-items: center`:

```scss
.my-feature__button {
  display: flex;
  align-items: center;
  font-size: var(--font-up-1); // the only line that actually changes anything
}
```

Better — keep only what differs from the base:

```scss
.my-feature__button {
  font-size: var(--font-up-1);
}
```

Only redeclare a base property when you are deliberately overriding it (e.g. switching `flex` to
`grid`), and when you do, it should be obvious from context that the override is intentional.

## 12. Name with BEM and keep nesting shallow

Discourse uses BEM, but modifiers are **standalone** `--modifier` classes, not `block--modifier`
suffixes. When repairing, hook into the existing block/element/modifier rather than inventing a
new flat class.

```scss
.topic-map {           // block
  &__title { }         // element
  &.--collapsed { }    // modifier (chained, standalone)
}
```

Bad:

```scss
.topic-map--collapsed { }   // suffix modifier, not our convention
.topicMapTitle { }          // camelCase, not BEM
```

Render the modifier as a class in the template (see section 8) instead of inferring state from DOM
position.

Ideally put the modifier **once**, on the top-level block, not repeated on every child element in the
HTML. Children that need to adapt reference the parent modifier with `.--modifier &`:

```scss
.topic-map {
  &.--collapsed {
    border-block-end: none; // the block itself reacts
  }

  &__title {
    .--collapsed & {
      font-weight: bold;    // a child reacting to the parent modifier
    }
  }

  &__details {
    .--collapsed & {
      display: none;
    }
  }
}
```

```hbs
<div class="topic-map --collapsed">   {{! modifier lives here, once }}
  <div class="topic-map__title">…</div>
  <div class="topic-map__details">…</div>
</div>
```

This keeps the source of truth in one place and avoids sprinkling `--collapsed` onto every child
in the template.

Keep nesting shallow — aim for ~2–3 levels. Deep nesting inflates specificity and makes a rule
hard to override later. If you are nesting just to "reach" an element, a scoped `&__element` is
the better hook.

Bad — five levels, high specificity:

```scss
.panel {
  .body {
    .list {
      li {
        .row { color: var(--primary); }
      }
    }
  }
}
```

Better — flat BEM element:

```scss
.panel__row {
  color: var(--primary);
}
```

## 13. General cleanup

Organizational hygiene that makes a stylesheet easier to repair next time.

**One rule block per selector.** Within a file, a selector should appear once. If the same
selector is written two or three times in the file, merge those declarations into a single block.
Repeated blocks fight over source order, hide each other, and make a regression hard to trace —
you fix one and the other quietly wins.

Bad — the same selector declared twice in one file:

```scss
.topic-map {
  display: flex;
}

// ...other rules...

.topic-map {
  gap: var(--space-2); // why is this separate?
}
```

Better — one block, nested with `&`:

```scss
.topic-map {
  display: flex;
  gap: var(--space-2);
}
```

Use BEM `&__element` / `&.--modifier` nesting so every part of a component lives inside its one
parent block, rather than as repeated top-level selectors.

**Order rules to match the page.** Within a file, arrange selectors in the order the elements
appear in the DOM, top to bottom — header before body before footer. Reading the stylesheet should
mirror scanning the rendered page, so the next person can find a rule by where they see it on
screen.

```scss
// Reads top-to-bottom like the rendered component.
.topic-map {
  &__header { }
  &__body { }
  &__stats { }
  &__footer { }
}
```

## Repair decision tree

### Style leaking elsewhere?

1. Find the broad selector.
2. Does it have a more specific class, use that
3. If not, scope to component/state
4. Add a rendered class if the state is known.
5. Avoid `!important`.

### Old UI looks weird?

1. Check whether old class/component still renders.
2. Delete stale CSS/imports if not.
3. Style the new component directly.

### Mobile broke?

1. Move logic to `common/`.
2. Use `@include viewport.until(sm)` / `from(sm)`.
3. Avoid fixed min-widths and guessed spacing.
4. Verify real narrow viewport.

### Overflow?

1. Try `min-width: 0`.
2. Try `minmax(0, 1fr)` for grid.
3. Constrain with `max-width`/`max-height`.
4. Use `overflow`, wrapping, or ellipsis intentionally.
5. Put scroll on the owning container.

### FormKit/select-kit weirdness?

1. Use FormKit args/modifiers.
2. Use `--form-kit-*` and `--d-input-*`.
3. Avoid global internals.
4. Check mobile and select-kit dropdown states.

## Verification checklist

- desktop viewport
- mobile viewport
- light and dark palettes
- Horizon if theme/foundation/sidebar/header touched
- RTL if physical positioning, icons, scroll fades, or nav touched
- iOS Safari / iOS-like behavior for scroll/chat/composer
- FormKit/select-kit contexts
- plugin surfaces sharing foundation classes
- deleted CSS imports removed
- before/after screenshots for UX changes
