---
name: discourse-writing-css
description: Use when writing or reviewing CSS/SCSS for Discourse core, themes, theme components, or plugins - applies Discourse's modified BEM rules, state class conventions, selector structure, CSS variable usage, and linting expectations
---

# Writing Discourse CSS

Use this skill for CSS/SCSS changes in Discourse core, bundled plugins, themes, and theme components.

The canonical source is `docs/developer-guides/docs/03-code-internals/25-css-guidelines-bem.md`. Read it when class naming is unclear or when touching a pattern that does not match the rules below.

## Workflow

1. Find nearby component, template, and stylesheet patterns before adding selectors.
2. Prefer component-specific block classes over broad descendant selectors.
3. Use Discourse's modified BEM naming for new component CSS.
4. Keep strings in templates translatable; do not split display strings to satisfy styling.
5. Lint every changed file with `bin/lint <paths>`.

## Modified BEM Rules

Discourse uses normal BEM for blocks and elements, standalone double-dash modifiers, and explicit state prefixes. The Discourse-specific modifier difference is that modifiers are separate classes (`class="block --modifier"`), not concatenated with the block or element name (`class="block--modifier"`).

| Purpose | Pattern | Example |
| --- | --- | --- |
| Block | `.block` | `.chat-message` |
| Element | `.block__element` | `.chat-message__avatar` |
| Modifier | `.--modifier` | `.--highlighted` |
| State or condition | `.is-foo`, `.has-foo` | `.is-open`, `.has-errors` |

- A block is a standalone component. A reusable Ember component usually gets a distinct block-level class.
- An element belongs to a block and should not be reused outside that block's context.
- A modifier changes appearance or variant. Modifiers are standalone classes so they can be reused without pure-BEM verbosity.
- Use `is-*` and `has-*` when naming state classes. Use modifiers for appearance or variant changes, including parent-level modifiers that style multiple child elements.

## Selector Structure

Visually nest element selectors under the block so related styles are easy to collapse and review.

```scss
.user-card {
  &__avatar {
    border-radius: 50%;

    &.--large {
      width: 4rem;
      height: 4rem;
    }
  }

  &.is-expanded {
    box-shadow: var(--shadow-dropdown);
  }
}
```

Use a direct modifier when the variant applies to the element itself.

```html
<button class="d-button --cancel"></button>
```

Use an indirect parent modifier when several child elements change together; this keeps the DOM cleaner than repeating the same modifier on every child.

```scss
.signup-form {
  &__input {
    .--error & {
      border-color: var(--danger);
    }
  }

  &__label {
    .--error & {
      color: var(--danger);
    }
  }
}
```

```html
<div class="signup-form --error">
  <input class="signup-form__input" />
  <label class="signup-form__label"></label>
</div>
```

## Utilities And Legacy CSS

Utility classes are not BEM blocks. Classes such as `.hidden`, `.show`, `.sr-only`, and `.clickable` are generic helpers and may stay single-purpose.

Do not copy legacy non-BEM patterns into new CSS for consistency. If a file contains old selectors such as `.block .element`, `.block-element`, or `.-modifier`, add new selectors with the current convention. Fix nearby legacy selectors only when the change is low risk and scoped to the work.

## Review Checklist

- New component selectors use `.block`, `.block__element`, `.--modifier`, and `.is-*` / `.has-*` correctly.
- Selectors avoid unnecessary specificity and broad descendant chains.
- Modifiers are direct when only one element changes and indirect when a parent condition affects multiple children.
- Styles use existing Discourse CSS variables and design tokens where practical.
- Template classes and stylesheet selectors match exactly.
- Changed files have been linted with `bin/lint`.
