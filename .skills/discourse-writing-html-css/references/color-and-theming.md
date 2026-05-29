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
