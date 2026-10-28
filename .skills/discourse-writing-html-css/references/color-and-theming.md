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
| `--d-hover`, `--d-sys-color-background-default-selected` | Hover / selected affordances |

Need a translucent color? Use the `-rgb` triplet variants inside `rgba()`:

```scss
background: color-mix(in srgb, var(--tertiary) 10%, transparent);
```

## Semantic design tokens (preferred for new UI)

[`app/assets/stylesheets/common/tokens.scss`](../../../app/assets/stylesheets/common/tokens.scss)
layers **semantic tokens** on top of the palette. Prefer these when one fits — they encode
intent and already handle light/dark via `light-dark()`:

- Text: `--d-sys-color-text-default`, `--d-sys-color-text-muted`, `--d-sys-color-text-accent`, `--d-sys-color-text-inverse`
- Icons: `--d-sys-color-icon-default`, `--d-sys-color-icon-muted`, `--d-sys-color-icon-danger`
- Borders: `--d-sys-color-border-default`, `--d-sys-color-border-input-focused`, `--d-sys-color-border-input`
- Surfaces: `--d-sys-color-background-default`, `--token-color-surface-hovered`, `--d-sys-color-background-default-selected`
- Sizing: `--d-sys-border-radius-sm|normal|large|full`, `--d-sys-border-width-sm`
- Weight: `--d-sys-font-weight-regular|medium|semibold|bold`

## General-purpose `--d-*` design vars

A family of app-wide design constants — `--d-sys-border-radius-md` (and `--d-sys-border-radius-lg`,
`--d-comp-Input-border-radius`), `--d-content-background`, `--d-sys-color-text-link`, `--d-hover`,
`--d-sys-color-background-default-selected` — for conventions like the standard corner radius and link color. Prefer these
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

`--d-sys-border-radius-md` is the standard corner radius used across the UI; `--d-sys-border-radius-lg`
is the larger step. Component radii derive from it — `--d-comp-DButton-border-radius`,
`--d-comp-Input-border-radius`, `--d-comp-NavPills-border-radius`, `--d-comp-DDiscourseTag-border-radius`. Override
`--d-sys-border-radius-md` to round everything consistently; override a component's own var to change
just that component. (Semantic-token equivalents: `--d-sys-border-radius-sm|normal|large|full`.)

### Buttons

`common/components/buttons.scss` defines the button hooks in `:root`, by variant:

```scss
// pattern: --d-button-{variant}-{text-color|bg-color|icon-color|border}[--hover]
// variants: default, primary, danger, success, flat
:root {
  --d-comp-DButton-color-background-primary: var(--tertiary);
  --d-comp-DButton-color-background-primary-hovered: var(--tertiary-hover);
}
```

Plus globals `--d-comp-DButton-border-radius`, `--d-button-border`, `--d-comp-DButton-motion-transition`. Override
these to restyle every button of a variant without touching `.btn` selectors.

### Inputs & form elements

`common/base/discourse.scss` defines input hooks: `--d-input-bg-color`, `--d-input-border`,
`--d-input-text-color`, `--d-input-focused-color`, `--d-comp-Input-border-radius` (each with a
`--disabled` variant where relevant). For FormKit layout (gutters, input widths), see the
`--form-kit-*` vars in `common/form-kit/_variables.scss` (`--form-kit-gutter-x/y`,
`--form-kit-max-input`, `--form-kit-{small,medium,large}-input`).

### Sidebar (and admin sidebar)

`common/base/sidebar.scss` defines the sidebar hooks: `--d-sidebar-background`,
`--d-sidebar-active-background`, `--d-sidebar-active-color`, `--d-sidebar-active-icon-color`,
`--d-sidebar-animation-time`/`-ease`, etc. The admin layout's sidebar adds `--d-sidebar-admin-*`
(e.g. `--d-sidebar-admin-background`) in `admin/sidebar.scss`. Override these to retheme the
sidebar in either context without overriding its internal selectors.

## Renaming variables

From time-to-time, variables may need to be renamed in core. To avoid breaking existing themes and plugins,
Discourse will automatically rewrite old variable names to new ones. A list of renames is maintained in
`stylesheets/variable-renames.json`, and is applied when CSS is compiled. This list also powers
a stylelint rule which will automatically rewrite old names to new names in source code.
