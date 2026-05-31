# Design System — code rollout plan

Bringing the layered design-token system into core, on branch `dev/design-system`.

## Naming (locked)

| Thing | Name |
|---|---|
| Feature / admin UI | **Design System** |
| Admin route | `/admin/config/design-system` |
| Site setting | `enable_design_system` |
| Color schemes | **Design System Light** / **Design System Dark** |
| CSS — raw layer | `--d-base-*` |
| CSS — semantic layer | `--d-system-*` |
| "tokens" | the individual DTCG values, not the feature |

## Model

- One DTCG source in core; `--d-system-*` references `--d-base-*` (self-contained,
  decoupled from the legacy ColorScheme — base palette is authoritative).
- The token CSS emits **always** (additive, inert). `enable_design_system` gates
  *behavior*: color-scheme selection, the admin section, and hiding the
  Color Palettes / Fonts nav items. Off = vanilla.
- Per-site customization = **per-theme overrides** layered over core defaults via
  the CSS cascade. Core token JSON is never written at runtime.

Out of scope here (separate follow-ons): graduating the blocks into core, and
hand-migrating core component CSS to `--d-system-*`.

## Milestones

### M1 — Token layer + gate (additive, mergeable alone)

**Phase 1 · Tokens**
- `common/design-system/{base.json,system.json}` — DTCG source (`--d-base-*`).
- `scripts/design-system/build.mjs` (no-dep Node) → generates
  `common/design-system/{base.scss,system.scss}`.
- Move `common/tokens.scss` → `common/design-system/tokens.scss` (the `--token-*`
  experiment, verbatim); `common.scss`: `@import "common/tokens"` → `@import "common/design-system"`.
- Verify: vars present globally; `--token-*` consumers (sidebar, form-kit) unchanged.

**Phase 2 · Setting**
- `enable_design_system` in `config/site_settings.yml` (hidden, default false).

### M2 — Color token-down

**Phase 3 · Schemes** — generate **Design System Light/Dark** ColorSchemes from
`base.json` (anchors + full ramps, light + `com.discourse.dark`); seed as built-ins.

**Phase 4 · Activation** — `enable_design_system` on → set the default theme's
`color_scheme_id` / `dark_color_scheme_id` to the DS schemes; off → restore.

### M3 — Admin section (port the POC)

**Phase 5 · `/admin/config/design-system`** — Colors / Fonts / Layout tabs.
- Per-theme overrides via the POC's `design_config` ThemeField target.
- Nav: show Design System when enabled; hide Color Palettes + Fonts when enabled.
- Colors save → cascade-override `--d-system-color-*` + update mapped scheme anchors.
  Fonts: family drives `base_font`/`heading_font`, rest are tokens. Layout: tokens.
- Semantic→anchor map: primary←text.default, secondary←surface.default,
  tertiary←interactive.default, header_*←default text/surface, selected←surface.selected,
  hover←surface.hovered, danger←text.danger, success←text.success,
  quaternary←surface.brand-hovered. Orphans: highlight, love → fixed defaults.

### M4 — Live editing

**Phase 6 · Override-CSS generation** — turn a theme's `design_config` overrides into
a `:root` override block compiled after core defaults (theme stylesheet + cache
invalidation). Reset = delete override → core default returns.

**Phase 7 · Tests + lint** — system spec (enable → schemes selected + vars present +
admin loads + nav swapped; disable → vanilla); `--token-*` consumers intact; `bin/lint`.

## Dependencies

P1→P3, P3→P4, P2→P4, (P1+POC)→P5, P5→P6. M1 ships on its own; each milestone is PR-sized.

## Pre-merge checklist

- **Revert `enable_design_system` default to `false`** — it's `true` on this branch only, so the design system is active for testing. It must not ship enabled.
