# CSS repair reference

Companion to the **Repairing existing CSS** section of `SKILL.md`.

Use this when fixing visual regressions, stale selectors, mobile layout bugs, overflow, FormKit
or select-kit styling, design-token issues, or broad foundation fallout.

The recurring repair pattern in Discourse is:

> Delete stale CSS, scope what remains, move device forks into `common/`, use tokens/FormKit APIs,
> and fix overflow by changing containment rather than adding another width.

## 1. Scope broad selectors

Broad selectors leak across Discourse because components, plugins, themes, and cooked content
reuse common class names.

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

```scss
// Kept topic-list font sizing on headers instead of leaking to category page cells.
td,
th {
  color: var(--d-topic-list-header-text-color);
}

th {
  font-size: var(--d-topic-list-data-font-size);
}
```

If a selector leaks, narrow it. Do not add `!important` or a deeper chain unless there is no
better hook.

## 2. Delete stale CSS before overriding

Before adding a repair rule, check whether the old class/component still exists:

```sh
rg "<selector>" app frontend plugins themes
```

If a component migrated to a new shared component, remove old selectors and imports. Do not keep
old CSS “just in case.”

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

```scss
.form-kit__field.--large .form-kit__container-content {
  width: 100%;
}

.form-kit__container {
  @include viewport.until(sm) {
    width: 100%;
  }
}
```

Use established variables:

```scss
var(--form-kit-max-input)
var(--form-kit-small-input)
var(--d-input-border)
var(--d-input-border-radius)
```

Avoid global internal overrides outside FormKit itself:

```scss
.form-kit__container-content {
  width: 100%;
}
```

That leaks into unrelated forms.

## 7. Tokens and semantic variables

Prefer:

```scss
var(--space-*)
var(--font-*)
var(--line-height-*)
var(--d-border-radius)
var(--d-input-border)
var(--content-border-color)
var(--primary-medium)
var(--secondary)
var(--token-color-*)
```

Avoid hardcoded colors and arbitrary one-off values unless they encode a real geometry constraint.

Bad:

```scss
padding: 13px;
border-radius: 7px;
color: #888;
```

Better:

```scss
padding: var(--space-3);
border-radius: var(--d-border-radius);
color: var(--primary-medium);
```

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

## Repair decision tree

### Style leaking elsewhere?

1. Find the broad selector.
2. Scope to component/state.
3. Add a rendered class if the state is known.
4. Avoid `!important`.

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
