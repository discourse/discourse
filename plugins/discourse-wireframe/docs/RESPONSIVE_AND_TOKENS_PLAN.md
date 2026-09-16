# Wireframe — responsive layouts + design tokens integration plan

## Context

Two architectural questions surfaced after the DnD overhaul shipped. The editor today produces **desktop-shaped** layouts authored against **arbitrary hex values** — both directions need a plan now so we don't paint ourselves into a corner that's expensive to back out of (persisted block args become contracts the moment we ship).

**Problem 1 — Responsive.** The editor currently builds a single, desktop-oriented layout. The only viewport-aware primitive is `viewport` conditions (`plugins/discourse-wireframe/.../blocks/conditions/viewport.js:52-152`) — these toggle entire blocks in/out, not adapt the same block. Forcing authors to build a parallel layout for every breakpoint is unworkable; we need a way for the same blocks to *adapt*.

**Problem 2 — Visual polish without CSS.** Block args today are either scalar hex strings (`wf-media-card.backgroundColor`) or hardcoded class hooks (`wf-cta-banner` reading `--primary-low` etc.). Authors picking arbitrary colors will produce themes that ignore the site's palette; authors with no controls will produce blocks that don't look intentional. Meanwhile core is moving toward semantic design tokens (dev.discourse.org topic 174320, merged April 2026 onto main): a 3-layer system (primitives → `--sys-*` → component tokens) starting with text colors, extending to fonts/layout next. The editor needs to plug into that catalog rather than fork its own.

Both questions affect the **persisted schema** — what gets serialized into theme files. Getting them wrong now means migration pain later.

## Direction 1 — Responsive layouts

### Current state (verified)

- Block args are **scalar** (one value per arg) — `wf-heading.gjs:16-39`, `wf-layout.gjs:33-99`. No per-viewport shape.
- `containerArgs` is a per-child namespace bag (`block-outlet.gjs:200-211`) holding things like `{ grid: { column, row, align, justify } }`. Layout reads it via `cellStyle()` (`wf-layout.gjs:243-256`).
- Conditions are **whole-entry visibility gates** — `viewport.js` supports `{type:"viewport", min:"lg"}` etc. but no per-arg responsiveness.
- Discourse core already has the primitives: `capabilities.viewport.{sm,md,lg,xl,2xl}` tracked media queries (`capabilities.js:70-111`), matching SCSS mixins (`viewport.scss:1-36`), and CSS container queries already in use (`group.scss`, `directory.scss`). The simulation toolbar (`simulation-controls.gjs:32-37`) plumbs simulated viewport into condition evaluation.

### Approach: hybrid container queries + opt-in arg overrides

**A. Container queries as the default adaptation mechanism (zero author burden)**

The layout block hosts a CSS container query context:

```scss
.wf-layout {
  container-type: inline-size;
  container-name: wf-layout;
}
.wf-layout--grid {
  /* default: respect author's columns */
  grid-template-columns: repeat(var(--wf-layout-cols, 12), 1fr);
}
@container wf-layout (max-width: 40rem) {
  .wf-layout--grid {
    /* collapse to 1 column below `sm` */
    grid-template-columns: 1fr;
  }
  /* row layouts wrap to stack below sm */
  .wf-layout--row { flex-direction: column; }
}
```

- Costs nothing to authors: existing layouts collapse sensibly out of the box.
- Container queries (not media queries) so a layout inside a sidebar narrows the same way it would on a phone — what matters is the *available width*, not the device.
- Tunable via layout args (e.g. `mobileCollapse: "auto" | "preserve" | "stack-each"`) so authors who want to keep a 12-column grid at all sizes can opt out.

**B. Responsive arg overrides for cases where adaptation isn't structural**

Some choices can't be CSS-only (different image, different copy length, different number of items shown). Introduce a **schema flag** on individual args: `responsive: true`. Storage shape:

```js
// In schema declaration:
title: {
  type: "string",
  responsive: true,
  default: "Hello"
}

// In persisted entry args (when overridden):
title: {
  default: "Welcome to our community",
  sm: "Welcome",
}

// In persisted entry args (when not overridden — the common case):
title: "Welcome to our community"
```

The runtime picks the matching breakpoint at render time using the existing `capabilities` service (or `context.simulation.viewport` when the editor is simulating). The schema flag stays opt-in per arg so blocks only carry responsive overhead where it makes sense.

**C. Per-viewport `containerArgs.grid` for explicit grid placements**

Authors of a 6×2 grid may want a phone layout where each block goes full-width and stacks. Allow `containerArgs.grid` to take the same default-plus-breakpoint shape:

```js
containerArgs: {
  grid: {
    default: { column: "1 / 4", row: "1" },
    sm:      { column: "1 / -1", row: "auto" }
  }
}
```

The structural change in `wf-layout.gjs:243-256` is small: `cellStyle()` picks the active breakpoint's overrides instead of reading the namespace bag directly.

### Inspector UX

For responsive args / containerArgs, render an "override" row under the base control:

```
Title          [ Welcome to our community            ]
  ↳ sm override [ Welcome                              ]  [×]
                [+ add tablet override]
```

The simulation toolbar's active viewport drives which override row is highlighted ("you're previewing mobile — this is the value being used"). Keeps the responsive surface invisible until the author opts in per-arg.

### Migration / persisted schema

Storage stays backward-compatible. Today's `title: "Welcome"` keeps working — only when the author adds an override does the arg promote to the object shape. A `serializeEntryForSave` pass (already exists at `mutate-layout.js:679-680`) can normalize: if all overrides equal the default, collapse back to scalar.

### Out of scope (defer)

- Per-condition variants (e.g. "this arg's value when a specific tag matches") — keep conditions as the visibility/swap mechanism.
- Device-class-only adaptation (touch vs. mouse) — use the existing condition flag.
- Authoring two completely different blocks for mobile vs. desktop — that's what conditions are for; the responsive mechanism above is for adapting the same block.

## Direction 2 — Design tokens / "look good without CSS"

### Current state (verified)

- Discourse just merged Phase 1 semantic tokens (text colors): `--sys-text-default`, `--sys-text-subtle`, `--sys-text-subtlest`, etc. (dev topic 174320, merged via cloud-hosting PR #305/306 in April 2026, then into core).
- 3-layer architecture confirmed: **primitives** (`--primary-300`, `--primary-700`) → **system semantic** (`--sys-text-*`) → **component** (`--topic-title-color: var(--sys-text-default)`).
- Roadmap signals: extend to **fonts and layout** next (post #57 from manuel — admin UI pages for colors / fonts / layout, JSON token files as the source of truth).
- VE blocks today are inconsistent:
  - `wf-cta-banner.gjs:21-81` — reads `--primary-low`, `--primary-medium` directly in its stylesheet. Stable, but not adjustable per-block.
  - `wf-media-card.gjs:85-94, 117-125` — exposes `backgroundColor` as a **raw hex string** via FormKit's `color` control, inlines it via `trustHTML`. Bypasses the palette entirely.
  - `wf-category-banner.gjs:102-106` — pulls colors from the category model via `--wf-category-banner-background` etc. Best of the three: indirected, source-of-truth-driven.

### Approach: blocks consume tokens, never raw values

**A. Replace the "color" control with a "token" control**

Add a new schema control type — `control: "token-color"` — that renders an inspector picker over the **catalog of semantic tokens** (filtered to color tokens). The persisted value is the token *name* (e.g. `"--sys-text-default"`), not the resolved hex. At render time the block emits `style="color: var(--sys-text-default)"`.

```js
// Block declaration:
titleColor: {
  type: "string",
  control: "token-color",
  default: "--sys-text-default",
  ui: { label: i18n("...title_color") }
}
```

Two pickers in parallel:
1. **Semantic colors** (the default — small curated list: text-default/subtle/subtlest, danger, success, ...).
2. **Palette colors** (escape hatch — primary/tertiary scales). Surfaced behind a "More colors" expander so the curated list reads as the primary path.

**Raw hex is the third tier**, locked behind an "Advanced" toggle, and persists with a clear marker (`{type:"custom", value:"#aabbcc"}`) so it's auditable in serialized themes.

**B. Token catalog as a registered service**

Centralize the catalog in a new service:

```js
// New: plugins/.../services/wireframe-tokens.js
@service tokens;

get colorTokens() {
  return [
    { name: "--sys-text-default",  label: "Text — default",  category: "Text" },
    { name: "--sys-text-subtle",   label: "Text — subtle",   category: "Text" },
    { name: "--sys-text-subtlest", label: "Text — subtlest", category: "Text" },
    { name: "--sys-color-danger",  label: "Danger",          category: "Status" },
    ...
  ];
}
```

The catalog reflects the tokens core ships. When core's token JSON file lands (post #57, post #59 from manuel — JSON-as-source-of-truth direction), this service reads from that JSON directly instead of duplicating the list.

**C. Font and spacing tokens follow the same pattern when they land**

The roadmap calls for `--sys-font-*` and `--sys-space-*` (or whatever core picks). Same picker pattern, different catalog. The schema can grow `control: "token-font"`, `control: "token-space"`. We design the picker once and reuse.

**D. Component-level tokens for VE itself**

Eventually VE blocks should declare their own component tokens that REFERENCE semantic tokens:

```scss
.wf-media-card {
  --wf-media-card-background: var(--sys-surface-default);
  --wf-media-card-title-color: var(--sys-text-strong);
  --wf-media-card-cta-color: var(--sys-text-default);
  /* etc. */

  background: var(--wf-media-card-background);
  .wf-media-card__title { color: var(--wf-media-card-title-color); }
}
```

Authors override component tokens via inspector controls, but each override is a token reference (or an Advanced raw value), never an undocumented hex. This makes themes auditable: "what colors does this block use" answerable by reading the SCSS.

### Migration / persisted schema

- Existing `wf-media-card.backgroundColor: "#aabbcc"` migrates to `{type:"custom", value:"#aabbcc"}` via a one-time `serializeEntryForSave` pass, OR stays as-is and the runtime accepts both shapes.
- New blocks ship with `control: "token-color"` from day one and persist token names.
- Migration is opt-in (per block) so we don't break themes that already shipped.

### Inspector UX

For a token control:

```
Background color
  ●  Surface — default       (= --sys-color-surface-default)
  ○  Surface — subtle
  ○  Tertiary
  ▾ More colors
    Primary 50 / 100 / 200 ...
    Custom hex...
```

The selected token's resolved color appears as a swatch beside its label so authors visually confirm what they're picking. Curated list at the top means most authors never see the escape hatch.

## Industry patterns — how WYSIWYG editors handle these problems

A brief survey of where the mature tools have landed. We don't need to invent a UX vocabulary from scratch; authors moving between tools should find ours familiar.

### Responsive editing — three dominant patterns

**Pattern 1 — Breakpoint switcher with cascade (Webflow, Framer, Builder.io, Wix Studio, Figma Sites)**

A breakpoint switcher sits in the top toolbar showing icons for desktop / tablet / mobile (sometimes more granular). Selecting a breakpoint:
- Resizes the canvas to that width.
- Switches the *editing context*: changes made here apply at this breakpoint and smaller (descending cascade — Webflow's "this property cascades down").
- Inspector controls show *which breakpoint owns the current value* via a dot indicator or "inherited from desktop" label.

Storage is per-breakpoint object on each property. Changes inherit downward unless overridden. Authors design once at desktop, override only what's needed at smaller sizes.

**Pattern 2 — Auto-adaptation (Framer's "Layout" mode, Figma Auto Layout, Squarespace Fluid Engine)**

The layout system itself reflows without per-breakpoint overrides. Stacks become columns, grids collapse, gaps scale. Authors specify constraints ("min item width: 200px, wrap when crowded"); the runtime decides the breakpoints.

Less control, less work. Best for content that's symmetric across viewports.

**Pattern 3 — Container queries (Framer 2024+, modern CSS-only tools)**

Same as Pattern 2 but the breakpoint is the *container's* width, not the viewport's. A card in a sidebar reflows like a card on a phone — same available width, same behaviour. Increasingly the default for new tools.

**Where to land**: we should adopt **all three layered**, in priority order:
- Container queries as the default ("free" — no author burden).
- Cascade breakpoint switcher for explicit per-arg overrides (familiar — matches Webflow / Framer expectations).
- Auto-adaptation primitives in `wf:layout` (grid → stack, gap shrink) baked into the layout block itself.

### Design tokens / colour picking — converged on one pattern

Webflow Variables, Figma Variables, Framer Tokens, Plasmic Style Tokens, Gutenberg theme.json palette all converged on:

1. **Curated picker first.** Swatches grouped by category (text, surface, accent...). Search box. Token name + swatch + (optionally) hex appears beside.
2. **"Detach" / "custom value" as a deliberate escape hatch.** Single button or expander. Persisted value is marked as custom so reviewers see it's an override.
3. **Indicator when a value is overridden vs. using the token default.** Dot, dashed border, "Custom" badge.
4. **Token references are the primary persisted shape.** Raw hex is the exception, not the rule.

Figma additionally lets authors *create* tokens inline ("create variable from this value"). Probably out of scope for v1; defer to core's admin token UI.

## Proposed UX

### A. Toolbar — breakpoint switcher (replaces or augments the simulation toolbar)

The existing `SimulationControls` already plumbs simulated viewport into condition evaluation. Promote it to a first-class breakpoint switcher:

```
┌──────────────────────────────────────────────────────────────────┐
│  ◀ Outline    [ Mobile ▿  Tablet  Desktop ]   Save  Publish ▾   │
└──────────────────────────────────────────────────────────────────┘
                  ▲ active = editing context
```

- Three buttons (mobile/tablet/desktop), one active.
- Active button = the breakpoint you're authoring for. Canvas resizes to that width.
- A subtle text label below the active button: `"Mobile · 375px"` / `"Tablet · 768px"` / `"Desktop · 1280px"`.

**Naming**: align with core's existing `sm` / `md` / `lg` / `xl` / `2xl` (`capabilities.js:70-111`), so we don't fork breakpoint names from the rest of the codebase. Toolbar labels can stay human ("Mobile / Tablet / Desktop") while the persisted breakpoint key is `sm` / `md` / `lg`.

### B. Inspector — responsive arg control

A responsive arg's row in the inspector picks up a small "breakpoint cascade" affordance:

```
┌─────────────────────────────────────────────┐
│  Title                              ◉ ─ ─    │  ← three dots: lg / md / sm
│  ┌─────────────────────────────────────────┐│      filled = override exists
│  │ Welcome to our community                ││      hollow = inherits
│  └─────────────────────────────────────────┘│
│  Editing: Desktop (cascades down)            │
└─────────────────────────────────────────────┘
```

When the user switches to "Mobile" in the toolbar, the same row reads:

```
┌─────────────────────────────────────────────┐
│  Title                              ◉ ─ ◉    │  ← sm override now exists
│  ┌─────────────────────────────────────────┐│
│  │ Welcome                                 ││
│  └─────────────────────────────────────────┘│
│  Editing: Mobile · inherits "Welcome to our  │
│  community" from Desktop                     │
│                              [Reset to desktop]│
└─────────────────────────────────────────────┘
```

- Hollow dot = inherits from a larger breakpoint.
- Filled dot = explicit override at this breakpoint.
- Hovering a hollow dot shows the inherited value.
- "Reset to desktop" only appears when an override exists.

This matches Webflow's pattern almost beat-for-beat. Authors who've used Webflow/Framer recognize it instantly.

### C. Inspector — token-color control

```
┌─────────────────────────────────────────────┐
│  Background color           ● Surface subtle │  ← swatch + name
│  ┌─────────────────────────────────────────┐│
│  │ Search tokens...                        ││
│  └─────────────────────────────────────────┘│
│                                              │
│  Surface                                     │
│    ▢ Default       ▢ Subtle*     ▢ Strong   │  ← * = currently selected
│  Text                                        │
│    ▢ Default       ▢ Subtle      ▢ Subtlest │
│  Status                                      │
│    ▢ Danger        ▢ Success                │
│                                              │
│  ▾ Advanced                                  │
│    Primary scale: 50 100 200 300 400...     │
│    Custom hex... [ #aabbcc          ]        │
└─────────────────────────────────────────────┘
```

- Header shows current selection (swatch + token's human name).
- Categories surface the curated semantic tokens first.
- "Advanced" expander unlocks the primary scale and raw hex (the escape hatch).
- Selecting a custom hex shows a small "Custom" badge next to the value in the inspector summary, signalling to other reviewers this is an override.

Implementation: a new component `inspector-form-controls/token-color.gjs` registered in `FORM_KIT_TYPE_BY_CONTROL` (`inspector-form.gjs:25-45`) with the existing FormKit `color` control as the fallback when "Custom hex" is chosen.

### D. Canvas — visual indicator that a block has responsive overrides

In the chrome's hover-state badge, show a small breakpoint icon when the block has any responsive overrides set:

```
        ┌─────────────────────────┐
   ↕ ▦  │ Media card · 3 overrides │   ← only on hover / select
        └─────────────────────────┘
```

Click the icon to jump the inspector to the responsive sections. Optional polish, but it surfaces hidden state authors would otherwise forget about.

### E. Simulation / preview distinction

Webflow and Framer separate **edit-at-breakpoint** from **preview-at-breakpoint**:
- Edit mode: canvas resizes; inspector edits values for that breakpoint.
- Preview mode: canvas resizes; inspector is read-only and shows the *resolved* value.

We can collapse this: while the inspector is open, you're editing. The "Preview" button (already on the toolbar today) hides the inspector and gives a clean canvas. No separate mode switch needed.

## Cross-cutting concerns

### Persisted-schema versioning

Both directions extend the persisted schema. We should pre-commit to one of:

- **Implicit promotion** (recommended): `title: "X"` and `title: {default: "X"}` both work; the serializer picks the smaller form. No version bump needed.
- **Explicit schema version**: add a `__schemaVersion: 2` per entry. More verbose but easier to migrate forward later.

I'd start implicit and only add the version field when a non-implicit migration is needed (haven't found a need yet).

### Conditions vs. responsive overrides

Keep them distinct:
- **Conditions** = whole-block visibility ("hide on mobile", "show only to admins")
- **Responsive overrides** = per-arg value swap on the same block
- **Container queries** = automatic layout adaptation without authoring effort

Document this in the editor onboarding so authors know which knob to reach for.

### Coordination with core's token initiative

Direction 2's success depends on core landing the next tranche of semantic tokens (fonts, spacing, surfaces). Until that ships, VE can only consume what exists (text colors today). A risk: if core's token names change before VE's UI ships, our catalog has to update. Mitigation: read tokens from a single source (core's JSON when it lands; until then, a small registered list in the VE service that we explicitly own and bump).

### What we lose by NOT planning now

- **Responsive**: if we ship the editor desktop-only and authors build hundreds of layouts, retrofitting per-arg responsive overrides means migrating every persisted block. The schema commitment is the expensive part, not the rendering.
- **Tokens**: same shape. If authors paint with hex strings today and we want to migrate them to tokens tomorrow, we have to either (a) write a value-to-token guesser (fragile), or (b) ask every site to redo their visual choices. Locking in `control: "token-color"` from day one for new blocks avoids both.

## Files this would touch (when we execute)

- **Responsive**:
  - `plugins/discourse-wireframe/assets/javascripts/discourse/blocks/wf-layout.gjs` — container-query SCSS + per-viewport `containerArgs.grid` reader in `cellStyle()`
  - `plugins/discourse-wireframe/assets/javascripts/discourse/lib/mutate-layout.js` — `serializeEntryForSave` collapse logic + responsive-arg helpers
  - `plugins/discourse-wireframe/assets/javascripts/discourse/components/editor/inspector-form.gjs` — responsive override row renderer
  - `plugins/discourse-wireframe/assets/stylesheets/wireframe.scss` — container-query rules for `.wf-layout`
- **Tokens**:
  - New: `plugins/.../services/wireframe-tokens.js` — token catalog service
  - New: `plugins/.../components/editor/inspector-form-controls/token-color.gjs` — picker UI
  - `plugins/.../components/editor/inspector-form.gjs:25-45` — register `token-color` in `FORM_KIT_TYPE_BY_CONTROL`
  - `plugins/.../blocks/wf-media-card.gjs` (and others) — migrate `control: "color"` → `control: "token-color"`
  - `plugins/.../assets/stylesheets/blocks/_*.scss` — introduce component tokens referencing `--sys-*`

## Recommended next steps

1. **Pick the implicit-promotion serialization shape now** (even though we're not implementing yet) and document it as a contract for any new arg shipped. This is the cheapest commitment to make and the one that's expensive to reverse.
2. **Stop adding raw `control: "color"` to new blocks.** Default to component-token CSS vars (like `wf-category-banner` does today) until the token picker exists.
3. **Wait on core's font/spacing token tranche** before committing VE's typography/spacing pickers — the catalog has to mirror what core ships.
4. **Build the container-query foundation in `wf-layout`** soon — it's a small, decoupled change that pays off immediately and doesn't depend on schema decisions.
5. **Defer the per-arg responsive UI** until we have at least one block that demonstrably needs it (the media card is the obvious candidate — different title length on mobile).

## Verification (when we execute)

- Responsive: place a 4-column `wf:layout` in an outlet, narrow the browser → grid collapses to 1 column under 40rem (container query, not viewport). Same layout inside a sidebar collapses at the sidebar's width, not the viewport's.
- Responsive arg overrides: set `title` on a `wf:heading` with an `sm` override, simulate mobile in the toolbar, see the override render; switch to desktop, see the default render.
- Token picker: open a `wf:media-card`'s inspector → background color shows the curated list with swatches; pick "Surface subtle" → persisted as `"--sys-surface-subtle"`, rendered as `style="background: var(--sys-surface-subtle)"`.
- Migration: load a theme with an old `backgroundColor: "#aabbcc"` value → renders identically; serializer normalizes the shape if the author saves.

## Out of scope (defer)

- A full design-system overhaul of VE's own chrome — that should follow core's lead, not race ahead.
- Theme-author tooling for editing semantic tokens (the JSON files manuel describes in post #57) — that's a core-side admin-UI question.
- Animation / interaction tokens — too early.
