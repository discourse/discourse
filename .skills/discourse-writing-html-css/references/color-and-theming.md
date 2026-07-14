# Color & theming reference

Companion to the **Color & theming** section of `SKILL.md`. The cardinal rule lives there:
never hardcode color, and never write a separate dark-mode block — the palette inverts. This
file is the variable inventory.

All variables are defined in
[`app/assets/stylesheets/color_definitions.scss`](../../../app/assets/stylesheets/color_definitions.scss)
and remapped per color scheme, so the same variable is dark in dark mode and matches any
theme's palette.

## The core palette

Each base color has a graduated scale blending it toward its opposite (`-low` is closest to
the background, `-high` closest to the foreground), plus numeric steps `-50`…`-900`.

| Variable family | Use for |
| --- | --- |
| `--primary` / `--primary-low` … `--primary-high`, `--primary-100`…`--primary-900` | Main text and foreground; low steps for subtle borders/backgrounds |
| `--secondary` | Main background / surface |
| `--tertiary` (+ scale) | Accent, links, primary actions |
| `--quaternary` | Secondary accent for themes |
| `--danger`, `--success`, `--love`, `--highlight` (each + `-low`/`-medium`/`-hover`) | Semantic states |
| `--header_background`, `--header_primary` | Header surface and its text |
| `--d-hover`, `--d-selected` | Hover / selected affordances |

Need a translucent color? Use the `-rgb` triplet variants inside `rgba()`:

```scss
background: rgba(var(--tertiary-rgb), 0.1);
```

## Semantic design tokens (preferred for new UI)

[`app/assets/stylesheets/common/tokens.scss`](../../../app/assets/stylesheets/common/tokens.scss)
layers **semantic tokens** on top of the palette. Prefer these when one fits — they encode
intent and already handle light/dark via `light-dark()`:

- Text: `--token-color-text-default`, `--token-color-text-subtle`, `--token-color-text-accent`, `--token-color-text-inverse`
- Icons: `--token-color-icon-default`, `--token-color-icon-subtle`, `--token-color-icon-danger`
- Borders: `--token-color-border-default`, `--token-color-border-focused`, `--token-color-border-input`
- Surfaces: `--token-color-surface`, `--token-color-surface-hovered`, `--token-color-surface-selected`
- Sizing: `--token-radius-small|normal|large|full`, `--token-border-width`
- Weight: `--token-font-weight-regular|medium|semibold|bold`

## General-purpose `--d-*` design vars

A family of app-wide design constants — `--d-border-radius` (and `--d-border-radius-large`,
`--d-input-border-radius`), `--d-content-background`, `--d-link-color`, `--d-hover`,
`--d-selected` — for conventions like the standard corner radius and link color. Prefer these
over inventing your own constant so a component matches the rest of the UI (and a theme can
retune them globally).

**Which to reach for:** a raw palette var when no token fits; a token or `--d-*` var when one
does.

## Theming components via their design vars

Many components expose `--d-*` custom properties as **theming hooks**: override the variable
(globally in `:root`, or scoped to a wrapper) to retheme the component without rewriting its
selectors or fighting specificity. Coverage varies by component and is still expanding, so
treat the listed source file as the authoritative, current set — these are entry points, not
exhaustive lists.

### Rounded corners

`--d-border-radius` is the standard corner radius used across the UI; `--d-border-radius-large`
is the larger step. Component radii derive from it — `--d-button-border-radius`,
`--d-input-border-radius`, `--d-nav-pill-border-radius`, `--d-tag-border-radius`. Override
`--d-border-radius` to round everything consistently; override a component's own var to change
just that component. (Semantic-token equivalents: `--token-radius-small|normal|large|full`.)

### Buttons

`common/components/buttons.scss` defines the button hooks in `:root`, by variant:

```scss
// pattern: --d-button-{variant}-{text-color|bg-color|icon-color|border}[--hover]
// variants: default, primary, danger, success, flat
:root {
  --d-button-primary-bg-color: var(--tertiary);
  --d-button-primary-bg-color--hover: var(--tertiary-hover);
}
```

Plus globals `--d-button-border-radius`, `--d-button-border`, `--d-button-transition`. Override
these to restyle every button of a variant without touching `.btn` selectors.

### Inputs & form elements

`common/base/discourse.scss` defines input hooks: `--d-input-bg-color`, `--d-input-border`,
`--d-input-text-color`, `--d-input-focused-color`, `--d-input-border-radius` (each with a
`--disabled` variant where relevant). For FormKit layout (gutters, input widths), see the
`--form-kit-*` vars in `common/form-kit/_variables.scss` (`--form-kit-gutter-x/y`,
`--form-kit-max-input`, `--form-kit-{small,medium,large}-input`).

### Sidebar (and admin sidebar)

`common/base/sidebar.scss` defines the sidebar hooks: `--d-sidebar-background`,
`--d-sidebar-active-background`, `--d-sidebar-active-color`, `--d-sidebar-active-icon-color`,
`--d-sidebar-animation-time`/`-ease`, etc. The admin layout's sidebar adds `--d-sidebar-admin-*`
(e.g. `--d-sidebar-admin-background`) in `admin/sidebar.scss`. Override these to retheme the
sidebar in either context without overriding its internal selectors.
