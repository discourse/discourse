# Plan: Phase 0 — Design-language foundation (tokens + keyboard convention)

Phase 0 of the approved editor-chrome revamp. Full roadmap archived at
`plugins/discourse-wireframe/docs/COMING-NEXT-EDITOR-CHROME-REVAMP.md`. This is
the substrate every later phase consumes.

## Context

The editor chrome's color is half-tokenized and half-hardcoded. The signature
orange is hardcoded (vars + 15 raw `rgb()` literals); on top of that, the sweep
found stray non-token colors the earlier audits missed: a second blue
(`#0077cc`, 4 sites) beside the Bootstrap `#007bff` (1 site), Bootstrap red,
warning yellows, and `color: white` chip text. None of it themes. Phase 0
establishes a coherent, themeable foundation: a brandable accent token, a
remap of stray colors to core semantics (a deliberate, user-approved visual
change), the `--wf-*` scale aligned to core, shared primitives, and the keyboard
convention.

## Verified color inventory + mapping (the work)

All sites confirmed by direct grep/read in `assets/stylesheets/admin/wireframe-chrome.scss`
unless noted.

### A. Accent — tokenize, ZERO visual change
The editor keeps its orange identity; it just becomes brandable tokens.
- Define in the `:root`/`.wireframe-shell` token block (near `:31-34` / `:1070`):
  `--wf-accent: #d97706; --wf-accent-rgb: 217 119 6;`
  `--wf-accent-strong: #b45309;` (selected/hover outline)
  `--wf-outlet-accent: #f59e0b; --wf-outlet-accent-rgb: 245 158 11;`
  `--wf-on-accent: #fff;` (chip/handle text — tokenized so it can flip if the
  accent ever goes light)
- Re-point: the 4 `--wireframe-block-*` vars (`:31-34`) + their ~16 `var()` uses;
  the orange raw literals → `rgb(var(--wf-accent-rgb) / α)` at
  `:120,130,2334,2340,2445,2452,2460,2679,3076,3080,3105,3215` and
  `rgb(var(--wf-outlet-accent-rgb) / α)` at `:1011,4917,4921`; the 6
  `color: white` at `:327,336,751,766,782,1049` → `var(--wf-on-accent)`. Update
  the stale comment at `:3073`. Defaults = today's exact values → no regression.
- Do NOT `transition` the custom property itself; transition concrete
  `box-shadow`/`outline-color`.

### B. Remap stray colors to core semantics — INTENTIONAL visual change
| Current literal | Sites | → |
|---|---|---|
| red `#dc3545` `rgb(220 53 69/α)` | 171, 2355, 3210, 3277, 4904 | `rgb(var(--danger-rgb)/α)` |
| red `#dc2626` `rgb(220 38 38/α)` | 5008 | `rgb(var(--danger-rgb)/α)` |
| blue `#007bff` `rgb(0 123 255/α)` | 3205 | `rgb(var(--tertiary-rgb)/α)` |
| blue `#0077cc` `rgb(0 119 204/α)` | 4870, 4950, 4991, 4996 | `rgb(var(--tertiary-rgb)/α)` (already beside `var(--tertiary)` borders) |
| warning `#ffc107` `rgb(255 193 7/α)` | 5629, 5630 | `rgb(var(--highlight-rgb)/α)` |
| warning icon `#ff9800` `rgb(255 152 0)` | 5635 | `var(--highlight)` |
| info badge `#f5a623` + `#000` text | 349-356 | `--highlight` bg + `--primary` text (preserve "distinct-from-red, readable" intent) |
| `wireframe.scss` error stripe `rgb(217 48 37/α)` | 105-106 | `rgb(var(--danger-rgb)/α)` |

Core triplets confirmed present: `--danger-rgb`, `--tertiary-rgb`,
`--highlight-rgb` (`app/assets/stylesheets/color_definitions.scss:28-30`).

### C. Black overlays / shadows
`rgb(0 0 0 / α)`: box-shadows (`:38,1509,2014,3005,3379,4342,4621`) → core
`--shadow-card`/`--shadow-dropdown` where they're elevation; subtle tints
(`:781,1048,1077,2670`) → keep or a `--wf-overlay-*` token. Black shadows are
conventional in both color modes (core does the same) → low risk; the win is
consistency. `wireframe.scss` ghost stripe `rgb(0 0 0/0.015)` (`:45-46`) → keep
or tokenize.

### D. `--wf-*` scale alignment to core
`--wf-radius` → `var(--d-border-radius)`; `--wf-radius-lg` →
`var(--d-border-radius-large)`; `--wf-gap-tight/gap/loose` →
`var(--space-1/2/3)`. Keep the `--wf-*` names (plugin namespace; `--d-*` is
core's). Core refs: `common/foundation/base.scss` (`--space`, `--d-border-radius`).

## Keyboard convention (Phase 0 = convention only)
- **Reuse core as-is**: `dTrapTab` (focus trap), `closeOnEscape`, `forceFocus`
  (`app/lib/dom-utils.js`), DButton `@ariaPressed`/`@ariaExpanded`/`@onKeyDown`;
  ARIA patterns `role=tablist/tab`, `role=listbox/option` (precedents
  `inspector-image-field.gjs`, `tabs.gjs`). Document the convention.
- **The general roving-focus modifier is Phase 1**, NOT Phase 0 (built with its
  first consumer — the palette grid — so the API is validated against real use).
  Recorded requirements for that Phase-1 ui-kit modifier (`dRovingFocus` in
  `frontend/discourse/app/ui-kit/modifiers/`):
  - DOM-order based (index `±1` horizontal, `±columnCount` grid — NOT the
    fragile `offsetTop/offsetLeft` geometry the `d-icon-grid-picker` uses today);
    single tab stop, Home/End, Enter/Space.
  - General enough to **subsume `rovingButtonBar`** (migrate its `d-editor` /
    `toolbar-buttons` consumers) AND to **replace the `d-icon-grid-picker` grid
    nav** — which means it must support both "move focus" (toolbar/rail) and
    "move highlight / `aria-selected` activedescendant" (listbox/grid-picker).
  - Those two core migrations are parity-tested follow-ups, gated on the modifier
    landing + proving out on the palette — not Phase 1 blockers.

## Shared primitives
Light-touch in Phase 0: define shared `panel` / `panel-header` / `section` /
`row` primitive classes + a consistent focus & selection treatment keyed off the
accent + scale. Surfaces adopt them as they're restyled in later phases.

## Files
- `plugins/discourse-wireframe/assets/stylesheets/admin/wireframe-chrome.scss`
  (token block + every remap above).
- `plugins/discourse-wireframe/assets/stylesheets/wireframe.scss` (error/ghost
  stripe).

## Risks & verification
- **Visual**: the accent must be pixel-identical (zero regression); the remapped
  semantics intentionally shift to the theme's hues. Verify with the
  `discourse-screenshots` skill across BOTH core themes (Foundation, Horizon) and
  **light + dark** — confirm errors read as danger, info/focus as tertiary,
  warnings as highlight; the info badge stays readable AND distinct from error
  badges; black shadows/overlays look right in dark mode.
- **Completeness**: the inventory above is the full verified set (self-swept, not
  from the agent reports which undercounted). A missed literal = a non-themeable
  spot.
- **No JS/behavior change** → existing 703 tests unaffected; `bin/lint` the SCSS;
  no new i18n.
- **Post-plan-mode bookkeeping**: update the archived roadmap doc + the Phase 1
  task to record (a) keyboard primitive moved to Phase 1 / ui-kit, (b) the
  `rovingButtonBar` + `d-icon-grid-picker` subsume-and-migrate requirement.
