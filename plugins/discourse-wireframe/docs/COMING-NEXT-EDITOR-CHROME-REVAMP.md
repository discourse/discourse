# Plan: Revamp the discourse-wireframe editor chrome

## Goal

Turn the editor chrome from independently-evolved surfaces into one
**systematized, senior-grade UI** — a shared design language applied across the
topbar, the left rail (palette + outline), the inspector, AND the on-canvas
selection chrome (floating block toolbar, resize/drag handles, drop-zones,
breadcrumb) — grounded in the patterns Gutenberg, Webflow, and Plasmic converge
on. Ships as a **phased roadmap**: one cohesive vision, implemented and approved
one phase at a time. Critically, "senior-grade" includes **keyboard,
accessibility, and touch** — which the current chrome largely lacks.

## How the chrome works today (mechanism & invariants)

- **Shell** (`components/editor/shell.gjs`) is a fixed full-viewport CSS grid
  (`grid-template-columns: 280px 1fr 320px`, `wireframe-chrome.scss:1082-1103`),
  `pointer-events:none` re-enabling only on **direct** children (`> *`,
  `:1106-1107`). The canvas is click-through so the live page underneath handles
  clicks. **Two invariants:** (a) the `> *` re-enable assumes the rail/panel/etc.
  are direct grid children; (b) the live page is inset to sit under the canvas by
  a SECOND hand-synced copy of the rail widths on `body`
  (`--wf-left-rail: 280px`/`--wf-right-rail: 320px` at `:1460-1461`, consumed as
  `padding-left/right` at `:1468-1469`, collapse mirrors `:1473`/`:1477`). Grid
  widths and body padding must stay in lockstep or clicks land in the wrong column.
- **Left rail**: Palette/Outline are two text-tab `DButton`s driven by
  `leftPanelTab` — **component-local tracked state with NO persistence and NO ARIA
  tab semantics** (`shell.gjs:48`, `:232-249`). Collapse state IS persisted
  (`leftCollapsed` localStorage) and mirrored to `body` via the `bodyClass` helper
  we recently added.
- **Topbar** (`.wireframe-toolbar`): brand + `OutletJumpSelect` left; persona +
  viewport `<select>`s (`simulation-controls.gjs:46-91`, natively accessible),
  dim, conditional warnings, undo/redo, publish indicator, primary Save, Exit
  right. Flat, no grouping/overflow.
- **Palette vs popover**: the SIDEBAR panel already builds RICH rows
  (`palette-panel.gjs:75`, adds `description` + `namespaceType`) and does NOT use
  `buildBlockPalette`. The POPOVER and grid cell-picker go through the lossy
  `lib/palette.js:18 buildBlockPalette` (`{name,displayName,icon,category}`).
  Consumers of the lossy shape: `block-chrome.gjs:1094`,
  `components/editor/drag-drop/grid-overlay.gjs` (`get palette`), and
  `editor-empty-drop-placeholder.gjs` → `editor-block-picker-menu.gjs`.
  `thumbnail`/`previewArgs` exist in core
  `frontend/discourse/app/lib/blocks/-internals/display-metadata.js:75-77` and are
  **unused**.
- **Palette/outline rows are keyboard-broken today**: `palette-entry.gjs` and
  `outline-panel.gjs:779` rows are `role="button" tabindex="0"` with click-only
  handlers and **no keydown** — Enter/Space do nothing; you cannot insert or
  navigate via keyboard. There is **no roving-tabindex/focus-trap/list-keydown
  infrastructure anywhere** in the plugin to inherit.
- **On-canvas chrome**: `block-toolbar.gjs` is mature (grip+name handle drag
  source `:590`; `actionItems` move/duplicate-split/detach/force-expand/
  image/delete; hamburger collapse via `toolbar-fit`; inline bold/italic/link with
  `@preventFocus` to preserve the ProseMirror selection; URL sub-mode). It
  declares `role="toolbar"` (`:535`) but is **NOT a roving-tabindex toolbar** (ARIA
  violation). The idle bar stays in the DOM at `opacity:0` (NOT `display:none`) so
  the drag-source modifier registration is stable — **a hard constraint**.
  Sibling affordances (resize handles `DResizeHandles`, grid track/cell handles,
  drop-zones, ghost/preview overlays, `block-breadcrumb.gjs`) all use the orange.
- **Inspector**: header + Args/Conditions/Raw JSON tabs over FormKit, with
  editor-specific field components; some commit through FormKit, some bypass it.
- **Tokens**: mostly Discourse design tokens, BUT the signature orange is
  hardcoded BOTH as `--wireframe-block-*` vars (`wireframe-chrome.scss:31-34`,
  ~16 `var()` uses) AND as **15 raw `rgb(217 119 6 / …)` / `rgb(245 158 11 / …)`
  literals** (`:120,130,1011,2334,2340,2445,2452,2460,2679,3076,3080,3105,3215,
  4917,4921`) that re-pointing the vars cannot reach.
- **Responsive prior art**: `services/wireframe-toolbar-fit.js` + `modifiers/
  toolbar-fit.js` measure chrome width via ONE shared `ResizeObserver`, coalesce
  into one `afterRender` read-all-then-write-all pass, and write a
  `data-wf-toolbar-fit` tier consumed by SCSS (`:940-966`). The service queries
  literal class names (`__handle/__format/__actions/__more`), a 3-tier enum
  (`full|narrow|narrower`), the attribute name, and a `fingerprint` re-measure
  protocol — all toolbar-specific couplings.

## Confirmed design decisions (from the user)

1. **Accent**: a single brandable accent token (default: today's orange),
   themeable. Implemented as a CHANNEL token (`--wf-accent-rgb: 217 119 6`)
   consumed as `rgb(var(--wf-accent-rgb) / <alpha>)` so the per-site alpha
   variants work — plus a `--wf-accent` solid for opaque uses.
2. **Left rail**: build the **icon+label activity-bar** with **Add** (palette) and
   **Layers** (outline tree), plus a wired **Issues** slot whose panel content is
   delivered in its own dedicated phase (it's more than a relocation — see below).
   Reserve future slots for **Content Outline**, **Patterns**, and a **Theme/Styles
   bridge** (Assets/Media not pursued). The redundant outline "outlets" view mode
   is removed. Decline a parallel tokens/variables store — Discourse theming owns
   that; the Theme bridge integrates rather than duplicates.
3. **Topbar**: **three zones + View menu** — left structure, center document
   anchor, right status·view·commit. dim + persona + viewport fold into a `View▾`
   menu (simulation is rarely toggled), keeping the **native `<select>`s inside the
   menu** (don't re-implement as custom rows — preserves their accessibility).
   Add a dirty/unsaved Save state.
4. **Inspector**: editor-specific controls stay editor-specific but become **proper
   FormKit custom controls via FormKit's API** (not core FormKit primitives —
   they won't be reused), so draft/validation/error handling flows through one
   path. **Extract a general responsive-fit service** from
   `wireframe-toolbar-fit.js` (see Phase 5 — it's a per-consumer config refactor,
   not a one-liner).
5. **Palette**: icon-tile grid; hover preview (with the safety constraints below);
   quick-inserter "+"; unify the popover UP to the panel's richness + add
   thumbnail/previewArgs; kill the mixed-facet chip row.
6. **On-canvas chrome**: bring the block toolbar, handles, drop-zones, overlays,
   and breadcrumb into the same language; restyle + tokenize without changing
   behavior.

## Cross-cutting concerns (apply to EVERY phase)

These came out of adversarial review and are not optional polish:

- **Keyboard & focus is a first-class deliverable.** Core already ships the
  focused pieces — `dTrapTab`, `closeOnEscape`, `forceFocus`, DButton aria — REUSE
  them. What's missing is a reusable roving-tabindex for lists/grids/trees (core's
  only grid pattern, in `d-icon-grid-picker`, uses fragile `offsetTop/offsetLeft`
  geometry). So **Phase 1 builds a general `dRovingFocus` modifier in core ui-kit**
  (`frontend/discourse/app/ui-kit/modifiers/`) — DOM-order based, built with the
  palette grid as first consumer, designed to **subsume `rovingButtonBar`** AND
  **replace the `d-icon-grid-picker` grid nav** (so it supports both move-focus and
  move-highlight/`aria-selected`). Phase 0 only reuses core's pieces + documents
  the convention. The palette and outline keyboard activation is a **correctness
  fix** (broken today), not an enhancement.
- **Accessibility**: icon-only controls need accessible names + a current/selected
  model (DButton has **no `@ariaCurrent`** — pick `aria-pressed` for toggles or
  `role=tab`+`aria-selected`; the in-repo precedent is
  `inspector-image-field.gjs`). The block toolbar's `role="toolbar"` must gain
  roving tabindex or drop the role — restyling must not amplify the current
  violation.
- **Touch / coarse-pointer**: provide a **tap-to-insert** path (the same handler
  that fixes keyboard insert), ≥24–44px targets on tiles/drop-zones, and a tap
  equivalent for any hover affordance — or explicitly scope touch out per phase.
- **i18n**: each phase lists the new `wireframe.*` keys it needs (Sentence case)
  and removes/repurposes dead keys (e.g. `category_core/plugin/theme` if the chip
  row goes).
- **Tests**: each phase names the assertions it breaks. Two are
  deletions/renames, not tweaks (the palette chip-row test; the fit-service
  module rename). Baseline is 703 green.

## Chosen approach — and why the alternatives lost

A **shared design-language foundation first, then per-surface phases**, each
independently approvable. *Why not redesign each surface independently?* That's
how the inconsistency arose. *Why not a big-bang rewrite?* Too risky against the
pointer-events / drag / selection / reactivity invariants; phasing keeps each
change reviewable and shippable. Rejected directional alternatives (merits kept
visible): re-base on `--tertiary` (loses edit-mode identity); keep two text tabs
(no scalability); minimal topbar declutter (no document anchor); migrate controls
into core FormKit (wrong layer — not reusable).

## Phased roadmap (one phase per approval cycle)

This is the **frame, not the full design**. Each phase gets its OWN deep-planning
cycle when we reach it (competing models / adversarial review as its stakes
warrant), and its **open decisions are surfaced at that phase**, not front-loaded
now. Phase bodies below are scoping summaries, not final designs.

### Phase 0 — Foundation: tokens + keyboard convention
DETAILED PLAN: `COMING-NEXT-EDITOR-CHROME-REVAMP-PHASE-0.md`. Scope EXPANDED by
the user: accent tokenization (zero-regression) PLUS remapping the stray
hardcoded Bootstrap/Material colors to core semantics (deliberate visual change).
- Accent → `--wf-accent`/`--wf-accent-rgb` (+ `-strong`, outlet variant,
  `--wf-on-accent`); re-point the `--wireframe-block-*` vars + ~16 uses + the
  orange raw literals + the 6 `color: white` chip-text sites. Zero regression.
- Remap (intentional visual change): red→`--danger-rgb`, BOTH blues
  (`#007bff` + `#0077cc`)→`--tertiary-rgb`, warning yellows/orange→`--highlight`,
  info badge→`--highlight`+`--primary`. Black overlays→core `--shadow-*`.
- `--wf-*` scale → reference core (`--space`, `--d-border-radius`).
- Keyboard = convention only (reuse core's `dTrapTab`/`closeOnEscape`/`forceFocus`/
  DButton-aria + document it). The `dRovingFocus` modifier is Phase 1 (see above).
- Verify: `discourse-screenshots` across Foundation+Horizon × light+dark (accent
  pixel-identical; remapped semantics shift to theme hues, intent preserved).

### Phase 1 — Palette + quick-inserter
- `BlockGrid` + `BlockTile` reading the RICH rows; **promote the popover/grid-cell
  picker up to the panel's richness** (not "retire the panel's shape"). Migrate
  all FOUR `buildBlockPalette` sites together: `lib/palette.js:18`,
  `block-chrome.gjs:1094`, `drag-drop/grid-overlay.gjs`, and the
  placeholder→picker pair. Add `thumbnail`/`previewArgs` to the shared shape.
- Sidebar → icon-tile grid + category section headers; **remove the chip row**
  (`palette-panel.gjs`); source → quiet per-tile badge or separate filter.
- **Hover/focus preview — inverted, safe order**: default to **thumbnail → icon+
  description card**; **live mini-render ONLY for blocks with NO `data` hook**
  (data-driven blocks — `recent-topics`, `featured-*`, `topic-card`,
  `category/tag-banner` — would fire an XHR per hovered tile). Render through a
  **pure render path with NO editor chrome** (no block-chrome wrapper, toolbar,
  drag source, or fit registration). Debounce open ~150–200ms (`discourseDebounce`,
  cf. `wireframe-inspector-args.js:101`), one preview at a time, FloatKit
  close-grace, error boundary, `prefers-reduced-motion` respected. Trigger on
  **focus as well as hover**.
- **Accessibility/scent**: each tile's accessible name = `displayName` +
  `description` (a visually-hidden span always in the DOM), so removing inline
  descriptions doesn't blind SR/keyboard users.
- **Quick-inserter** (`editor-block-picker-menu.gjs` + the "+"): autofocus search
  + small grid of drop-target-valid blocks + **Browse all** → opens/focuses the
  sidebar. Keyboard: combobox/listbox semantics, roving tabindex, Enter inserts;
  tap-to-insert.
- **Build the `dRovingFocus` ui-kit modifier HERE** (first consumer = palette/
  inserter grid): DOM-order based (±1 / ±columns), single tab stop, Home/End,
  Enter/Space, supports move-focus AND move-highlight. Its own deep-plan +
  adversarial review (it's a core ui-kit primitive). Gated follow-ups (parity-
  tested, not blockers): migrate `rovingButtonBar` consumers + the
  `d-icon-grid-picker` grid nav onto it.
- Tests: **rewrite/delete** the chip-row test (`palette/palette-panel-test.gjs`
  ~40-53); update entry/search/empty assertions; keep
  `.wireframe-empty-drop-placeholder__hint` or update `block-tabs-add-test.gjs`.
  i18n: "Browse all", "no results", suggested header, inserter search placeholder;
  remove/repurpose dead `category_*` keys.

### Phase 2 — Activity-bar + outline consolidation
- **Activity-bar (icon+label):** Add / Layers, switching the wide panel, with the
  **Issues slot wired** (its content lands in Phase 2b); reserve slots for Content
  Outline / Patterns / Theme bridge.
- **Outline consolidation:** remove the tree/outlets view-mode toggle
  (`outline-panel.gjs:55-56`, `:419-420`, `:624-635`, `:692-718`) + its SCSS
  (`&__view-switch`/`&__view-tab`, `wireframe-chrome.scss:1484-1492`) + dead i18n
  (`view_tree`/`view_outlets`/`outlets.block_count`). The Layers tree (grouped by
  outlet, collapsible) is the single view. **Correction from review:** the tree's
  outlet header currently `selectOutletRoot`→`selectOutlet` (`:340-343`, `:750`)
  which SELECTS but does NOT scroll — the scroll-into-view lived only in the
  deleted `jumpToOutlet` (`:439`, wired to the summary cards) and the topbar
  `OutletJumpSelect`. So **re-home the `scrollIntoView` one-liner onto the header
  select** (the `.wireframe-outlet-boundary[data-outlet-name]` query, currently
  duplicated in both deleted spots) so the Layers tree becomes the navigation+
  scroll path. No outline test asserts the viewMode toggle (verified) — no test
  churn.
- **Invariant work (not one-liners):** keep the icon-rail and panel as **direct
  `> *` grid children** (or extend the `:1106` re-enable) so the rail doesn't go
  click-dead; restructure the shell grid (`:1082-1097`) AND update the **body
  rail-mirror in lockstep** (`:1460-1477`) via a single shared width token.
- Active-panel selection is **new local state + localStorage** (today's tab state
  does NOT persist — new work, not a mirror). No new body class unless a panel
  changes rail geometry.
- A11y: accessible name per icon+label entry + a chosen current-state model
  (`aria-pressed` or `role=tab`+`aria-selected`; precedent
  `inspector-image-field.gjs`).

### Phase 2b — Issues panel
Its own phase because it's more than a relocation — the error copy needs real work.
- **Relocate**: move the validation list out of the topbar into the Issues rail
  slot, grouped by outlet + searchable (à la Plasmic). Reuses
  `wireframeValidation.validationWarnings`
  (`services/wireframe-validation.js:41`, `{outletName, message}`) and
  `hasValidationWarnings` (`:60`). The only other consumer is the publish review
  drawer (`publish-review-drawer.gjs:155-164`, untouched); the inspector's error UI
  flows through FormKit independently — no reactivity break. Remove from
  `shell.gjs` the warnings button (`:161-172`), inline panel (`:205-223`), and
  `warningsPanelOpen`/`toggleWarningsPanel` (`:47,102-104`); delete the SCSS
  (`.wireframe-btn-warnings` + `.wireframe-warnings-panel`,
  `wireframe-chrome.scss:1133-1182` — note `grid-row:2`, reconcile with the grid);
  repurpose i18n `warnings_button_title`/`warnings_panel_title`. No test asserts the
  warnings UI.
- **Improve the error copy (the real work)**: today the panel surfaces the **raw
  blocks-API messages**, which were written for hand-authored theme developers, not
  this editor's users. Design an editor-facing message layer (clearer wording, the
  offending block/outlet named in human terms, likely a fix hint). This needs its
  own deep-planning pass (message taxonomy, i18n, where the mapping lives —
  editor-side vs. enriching the validator).
- **Click-to-select (nice-to-have)**: the validator stamps `__failureReason` per
  entry, so warnings can carry a blockKey → clicking an issue selects + reveals the
  offending block. Requires threading blockKey through `validationWarnings`.
- Sequencing: fills the Issues slot wired in Phase 2; can run immediately after.

### Phase 3 — Topbar (three zones + View menu)
- Left structure / center **document anchor** (outlet/page title) / right
  status·view·commit. Fold dim + persona + viewport into a `View▾` FloatKit menu
  **keeping the native `<select>`s inside**. Dirty/unsaved Save signal (touches
  `.wireframe-btn-save` — see `editor-shell-toolbar-test.gjs`). Responsive overflow
  reuses the Phase-5 general fit service (so its config must be designed first).
- The warnings button is gone (moved to the Issues panel in Phase 2b). The topbar's
  `OutletJumpSelect` is likely absorbed by the document anchor — decide at phase
  start (Open decision).

### Phase 4 — Outline (correctness + polish)
- **Correctness**: add keyboard activation (rows are non-activatable today) — tree
  pattern (Up/Down rows, Right/Left expand/collapse, Enter select) via the Phase-0
  primitive. Inline hover row-actions (delete/duplicate/visibility). Drag
  affordance (grip + cursor); keep existing drag/selection wiring.
- **Perf**: fold new per-row data into the single `#decorateRow` pass (don't add
  per-row live getters in the `{{#each}}`); drive keyboard-active off existing
  `wireframeSelection` or a single imperative `data-active` (not a per-row
  `@tracked` index → N re-renders/keypress); mount row actions one-at-a-time.
- Tests: `outline/outline-panel-test.gjs` (~8 tests on `.outline-block*`).

### Phase 5 — Inspector consistency + general fit service
- Re-register editor-specific controls as **FormKit custom controls** via FormKit's
  API; standardize look + route validation/errors through one path. (Changes
  inspector DOM/error markup — many inspector tests update.)
- **Extract a general responsive-fit service** from `wireframe-toolbar-fit.js`:
  this is a per-consumer config refactor, NOT just "keep the batching." Parameterize
  the measured selectors, the tier set (toolbar wants `full|narrow|narrower`;
  topbar/inspector want their own), the attribute name, and the `fingerprint`
  re-measure protocol. **Move the batching intact** (single ResizeObserver +
  afterRender read-all-then-write-all). Add an invariant test (K targets → one
  measure pass, zero interleaved writes). The rename moves
  `unit/services/wireframe-toolbar-fit-test.js` (import + module name) with it.
- Drive panel-width-adaptive inspector controls off this service; add a clear
  selected-block ↔ canvas indicator.

### Phase 6 — On-canvas selection chrome
- Restyle the block toolbar + `.wireframe-block-toolbar*` SCSS
  (`wireframe-chrome.scss:695-977`) into the shared language. **Hard "do-not-break"
  list:** never `display:none` the idle bar (keep `opacity`, preserves the drag
  source); keep the four fit-measured class names (or update the service same
  phase); add roving tabindex to satisfy `role="toolbar"` (`:535`) OR drop the
  role — and don't fight the inline-format `@preventFocus` selection retention.
- Unify resize handles (`DResizeHandles`), grid track/cell handles, drop-zones,
  ghost/preview overlays, and `block-breadcrumb.gjs` on `--wf-accent` + shared
  radii/spacing. Preserve the pointer-events carve-outs.
- Optional Plasmic-style floating "+" opening the Phase-1 quick-inserter (open
  decision). Tests: `block-toolbar-overflow-test.gjs`,
  `block-toolbar-duplicate-test.gjs` — the latter two are the **recently-re-enabled
  flaky tests**; restyling risks re-destabilizing them.

## Open decisions (yours)
- **`OutletJumpSelect` fate** (Phase 3): absorb into the document anchor, keep as
  a quick-nav, or drop entirely (the Layers tree + Issues panel already navigate).
- **Reserved-panel ordering**: which of Content Outline / Patterns / Theme bridge
  comes first after this initiative.
- Exact `--wf-accent` default hue (keep today's orange vs. refine).
- Quick-inserter "suggested" set: container-valid / recents / curated.
- Issues panel grouping: by outlet (matches the data) vs. by severity/type.
- Whether Phase 6 adds the floating "+", and how minimal the toolbar's resting
  state should be (Gutenberg full bar vs. Webflow lean label).

## Risks & verification
- **Invariants**: pointer-events click-through + the grid↔body-padding rail mirror
  (Phase 2); `> *` direct-child re-enable vs. an activity-bar wrapper (Phase 2);
  drag-source registration depending on the idle-toolbar-in-DOM rule (Phase 6);
  the fit-service couplings (Phases 3/5/6); FloatKit z-index — hover preview + View
  menu auto-clear chrome via the `:5227` blanket `.fk-d-menu/.fk-d-tooltip {
  z-index:1500 }` rule **only if built with FloatKit** (they will be).
- **Token migration completeness** (Phase 0): the 15 raw `rgb()` literals are a
  certainty to miss without the channel token, not a "risk."
- **Live preview** (Phase 1): network fetch per data-block tile unless inverted +
  pure-render-path + debounced + capped, as specified.
- **Fit-service** (Phase 5): observer storm / layout thrash if the batching
  discipline isn't moved intact; guard with the invariant test.
- **Outline** (Phase 4): per-row reactive work amplifying re-render; keep to one
  `#decorateRow` pass.
- **Verification per phase**: `bin/qunit plugins/discourse-wireframe/test/javascripts`
  green (updating the named tests); `bin/lint --fix`; manual browser pass (drag,
  select, collapse, insert, enter/exit, **keyboard-only**, **touch**) across the
  two core themes + light/dark via the `discourse-screenshots` skill. Watch the
  two re-enabled flaky toolbar tests in Phase 6.
