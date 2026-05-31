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

- One DTCG source in core; in the JSON, `--d-system-*` references `--d-base-*`
  (self-contained, decoupled from the legacy ColorScheme — base palette is
  authoritative). At runtime only `--d-system-*` is emitted; base values are inlined.
- A Ruby resolver (`DesignSystem::Tokens`) reads the JSON and is the single source
  for **both** the `--d-base-*`/`--d-system-*` CSS **and** the derived legacy
  ColorScheme anchors — no committed SCSS, no Node build, nothing hand-copied.
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
- ~~`scripts/design-system/build.mjs` (no-dep Node) → generates
  `common/design-system/{base.scss,system.scss}`.~~ **Superseded by Phase R** —
  generated in Ruby at compile time; the build script + committed SCSS are removed.
- Move `common/tokens.scss` → `common/design-system/tokens.scss` (the `--token-*`
  experiment, verbatim); `common.scss`: `@import "common/tokens"` → `@import "common/design-system"`.
- Verify: vars present globally; `--token-*` consumers (sidebar, form-kit) unchanged.

**Phase 2 · Setting**
- `enable_design_system` in `config/site_settings.yml` (hidden, default false).

### M1.5 — Ruby token compiler (supersedes the Node build + hardcoded anchors)

**Phase R · `DesignSystem::Tokens`** — one Ruby module reads `base.json` +
`system.json` and is the single source for both outputs:
- `.css` → a `:root{ --d-system-* }` block (**semantic layer only**), injected into
  the **`common`** stylesheet at compile time (`Compiler#compile_asset` `when "common"`
  → `Importer#import_design_system_tokens`). Base palette values are **inlined** into
  the system tokens (`--d-system-color-surface-default: light-dark(#fff, #1b1b1f)`),
  so `--d-base-*` is **not** exposed as CSS — base is an authoring concept in the
  JSON, not a runtime variable (nothing references it; checked). `common` is not
  light/dark-split, so `light-dark()` belongs there. Resolved values are unchanged,
  so computed styles don't change — only the emitted CSS is cleaner.
- `.color_scheme(:light/:dark)` → the **Design System Light/Dark** anchors, feeding
  `ColorScheme::BUILT_IN_SCHEMES` — replacing the hand-copied hashes.
- Semantic→anchor map (locked): primary←text.default, secondary←surface.default,
  tertiary←interactive.default, header_background←surface.default,
  header_primary←text.default, highlight←surface.highlight, selected←surface.selected,
  hover←surface.hovered, danger←text.danger, success←text.success, love←text.love;
  quaternary = fixed default (unused by the DS). Light values reproduce the current
  scheme exactly; only highlight/love **dark** values change (now scale-derived /
  dark-adaptive, were frozen).
- New tokens: base `yellow` + `pink` scales; system `color.surface.highlight`,
  `color.text.highlight` (the `<mark>` legibility colour — no legacy anchor) and
  `color.text.love`. Starter ramp values, to be design-reviewed.
- Cache-bust: add `common/design-system/*.json` to `Manager.list_files` (the `*.*css`
  glob never covered the JSON), so a token edit recompiles `common`.
- **Removed:** `scripts/design-system/build.mjs`, the committed
  `base.scss`/`system.scss`/`_index.scss`; `common.scss` imports the legacy
  `tokens.scss` directly.

### M2 — Color token-down

**Phase 3 · Schemes** — ~~generate~~ **Design System Light/Dark** ColorSchemes;
anchors now **computed** by `DesignSystem::Tokens` (Phase R) from the semantic
tokens — not hand-copied. Ramps (primary-50..900, tertiary-low, …) still computed
by Discourse from the anchors. Seeded as built-ins.

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

### M4 — Per-theme overrides (semantic layer only)

**Phase 6 · A theme declares semantic-token overrides; core regenerates that
theme's `--d-system-*` CSS and its legacy color anchors at compile time (no
per-theme ColorScheme records, no new trigger).** Locked decisions:
declared as **`tokens/system.json`** (DTCG, **semantic layer only** — base stays
core-controlled); **merge** over core defaults (declare only what changes);
tested via **discourse-d-system-blocks**. Same `DesignSystem::Tokens` resolver
as Phase R, parameterized per theme.

- **R1 · Resolver overrides** ✅ — `DesignSystem::Tokens` merges a theme's
  `design-system.json` over the core system layer (base always core) and gains
  `theme_css(overrides)` (emits only the overridden `--d-system-*`, resolved) and
  `color_scheme(mode, overrides)` (full anchors from the merged layer).
- **R2 · Theme file recognition** ✅ — `design_system` target in `Theme.targets`
  + a `FILE_MATCHER` for **`design-system.json`** (theme root, type `:json`, name
  `design-system`). Rootless file; core wraps it under `d-system` on read. Base
  files are not recognized — semantic layer only.
- **R3 · Per-theme CSS** ✅ — `Compiler#compile_asset` THEME_TARGETS branch
  (`common_theme`) appends `importer.import_theme_design_tokens`: reads the baked
  `design_system/design-system` field via `Theme.list_baked_fields`, emits
  `theme_css` (only overridden tokens). Loads after core `common`, so overrides
  win via the cascade. Reset = remove the file → core defaults return. JSON folds
  into the theme digest (`design_tokens_digest`) so edits recompile.
- **R4 · Per-theme legacy scheme** ✅ — no records, no new trigger. The legacy
  anchors already flow into `$primary…` SCSS vars at compile time via
  `Importer#color_variables`; when the theme ships `design-system.json` it merges
  the token-derived anchors (`color_scheme(mode, overrides)`) over the assigned
  scheme there, so the ramps (primary-low, tertiary-hover, …) recompute from the
  tokens. Mode = dark when compiling the theme's `dark_color_scheme_id`, else
  light. JSON folds into `color_scheme_digest` for cache-busting. (The theme keeps
  its assigned light/dark scheme as the mode handle — the fixture's DS Light/Dark
  assignment suffices; tokens just substitute the anchor values.)
- **R5 · Test** — add `design-system.json` to d-system-blocks with a few semantic
  overrides; verify the theme's `--d-system-*` + scheme reflect them and that
  removing the file restores core defaults.

(Admin-editable tokens — Phase 5 editors writing `tokens/system.json` — layer on
top of this once the file-based path works.)

**Phase 7 · Tests + lint** — system spec (enable → schemes selected + vars present +
admin loads + nav swapped; disable → vanilla); `--token-*` consumers intact; `bin/lint`.

## Dependencies

P1→P3, P3→P4, P2→P4, (P1+POC)→P5, P5→P6. M1 ships on its own; each milestone is PR-sized.

## Pre-merge checklist

- **Revert `enable_design_system` default to `false`** — it's `true` on this branch only, so the design system is active for testing. It must not ship enabled.
