# Things to revisit

Open questions and deferred work for the wireframe plugin. Each
entry: what, why deferred, and what'd unblock it.

## Editor-only CSS actually shipping only to staff

**Status**: ✅ Resolved for CSS (PR #40345). ✅ Resolved for JS (commit
`500978517cd`).

**What**: Both the plugin's editor-only **JS** and editor-only **CSS**
now download only when `staff?` is true.

- **JS**: every editor service, modifier, chrome component, and
  editor-only lib helper lives under
  `plugins/discourse-wireframe/admin/assets/javascripts/`, which is
  auto-detected and compiled into the staff-gated admin entrypoint.
- **CSS**: `admin/wireframe-chrome.scss` (editor chrome) is registered
  with the `:admin` target in `plugin.rb`, so it compiles into the
  `discourse-wireframe_admin` bundle and is served only when `staff?`.
  `wireframe.scss` (universal block content rendered on live pages)
  stays unconditional.

**How CSS was unblocked**: PR #40345 ("DEV: Allow plugins to register
admin-panel-specific CSS") added an `:admin` target to `register_asset`
— exactly the core change this note called for. CSS registered with
`:admin` routes into a per-plugin `<plugin>_admin` bundle
(`DiscoursePluginRegistry.admin_stylesheets`,
`lib/discourse_plugin_registry.rb`) that
`Discourse.find_plugin_css_assets` emits only when `include_admin` is
set, and the stylesheet views pass `include_admin: staff?`. We adopted
it by changing the registration to:

```ruby
register_asset "stylesheets/admin/wireframe-chrome.scss", :admin
```

The file already lived at the conventional `assets/stylesheets/admin/`
path, so no file move was needed.

**Note**: the gate is `staff?` (not strictly `admin?`), matching the
editor JS gate, so CSS and JS delivery stay symmetric.

## Per-arg responsive overrides

**Status**: ⚠️ Deferred. Foundation exists (`@container` rules on
`wf:layout` collapse grid/row layouts at <40rem); per-arg **content**
variation (e.g. different headline text on mobile vs desktop) is the
next-level feature but is not built yet.

**Why deferred**: doing this consistently with the `@container`
foundation means resolving each block's content per **container
width**, not viewport width. That needs per-block `ResizeObserver`
infrastructure plus a cascade-dot inspector UI. Not enough author
demand today to justify the complexity — the existing `viewport`
condition mechanism (whole-block visibility) covers the
"different block on mobile" case via alternating block instances.

**Prior-art note**: Discourse's own `meta-branded-theme` PR #69 uses
**zero** container queries — pure viewport mixins
(`@include viewport.until(lg)` etc.). Webflow / Framer / Tailwind
also viewport-based for per-arg content. Our `wf:layout` container
queries are deliberately ahead of where the rest of Discourse is;
when we add per-arg overrides we should align them with the
foundation rather than match the in-house viewport pattern.

**When we resume, design notes from prior exploration**:

- **Signal**: container width (`ResizeObserver` per block, opt-in via
  `responsive: true` schema flag). NOT viewport. Aligns with the
  structural-collapse foundation.
- **Persisted shape**: mobile-first object —
  `{default, sm?, md?, lg?, xl?, "2xl"?}`. Scalar by default; promote
  to object on first override; `serializeEntryForSave` collapses back
  to scalar when all overrides equal `default`. Backward-compatible
  with existing scalar values.
- **Resolution semantics**: Tailwind-style. Start with `default`,
  walk `sm → md → lg → xl → 2xl`, update result to each active
  breakpoint's value if it has one. Largest active override wins.
- **Schema**: add `responsive: true` as a valid arg-schema property
  in core (`frontend/discourse/app/lib/blocks/-internals/validation/block-args.js`,
  add to `VALID_BLOCK_ARG_SCHEMA_PROPERTIES`). Loosen value validation
  to accept the responsive object shape when the flag is set.
- **Helper**: new universal lib `resolve-responsive.js` — pure
  function `(value, breakpoints) → resolved`. Universal because
  blocks render on live pages too.
- **Container tracking**: new universal modifier
  `track-container-breakpoints.js` wrapping `ResizeObserver`. Reports
  `{sm, md, lg, xl, "2xl"}` to a callback whenever the element's
  inline-size crosses a threshold. Per-block opt-in; debounced.
- **Inspector UI**: cascade-dot row beside each responsive field —
  one dot per slot (`default` + each breakpoint). Filled = explicit
  override at that slot; hollow = inherits from a smaller slot.
  Current "editing slot" highlighted; clicking another slot's dot
  switches the simulation toolbar to that mode.
- **Simulation toolbar → edit slot**: map `real → default`,
  `mobile → sm`, `tablet → md`, `desktop → xl`. Inspector writes
  edits to the active slot. Canvas resizes to a width matching the
  simulation so the author sees the right content.
- **Pilot block**: `wf-heading.text` — smallest, most-edited field.
  After it works there, opt in `wf-paragraph.text`,
  `wf-cta-banner.title`, `wf-media-card.title`, etc.

**What'd unblock**: clear author demand for per-arg content variation
that can't be expressed via `viewport` conditions on alternating
blocks. Reasonable triggers: a theme author asks for it; we see
authors building duplicate blocks just to vary content; the editor's
own demo content needs it.

## Patterns (editor-time reusable compositions)

**Status**: ⏸️ Planned, deferred. Full implementation plan drafted; shelved to
explore code-defined composite blocks first (the two concepts are related — a
pattern is the runtime/author-saved version of what a composite block hardwires).

**What**: PLAN.md Phase 8 "Patterns" — select a block subtree on the canvas, save
it as a named reusable composition that appears in the palette's (currently empty)
`Patterns` tab; dragging it into a layout expands its blocks at the drop point.

**Confirmed design decisions** (so we don't re-litigate on resume):

- **Detached copy semantics.** Inserting deep-copies the subtree into the layout as
  ordinary entries — no ongoing link to the pattern definition. This makes patterns
  a purely editor-time, staff-only construct: nothing about them ships to the live
  page or to non-staff users. (Rejected the synced/linked alternative for v1.)
- **Per-theme storage** via a new `block_pattern` ThemeField type (sibling to
  `block_layout` = type 9), so patterns ride the theme export/import/Git bundle and
  inherit the `-customizations` Git-import child redirect. Value shape:
  `{schema_version, title, icon, description, blocks: [...]}`, where `blocks` is the
  same entry shape as a `block_layout` `layout` array (so the existing recursive
  validator and the `BlockLayoutUploads` walker apply unchanged). One field per
  pattern; the field `name` is a stable slug, the human title lives in `value`.
- **Name + icon + description palette rows** (no live thumbnail in v1 — that would
  depend on the unbuilt preview-token work).

**Implementation sketch**: mirror the block-layout plumbing —
`Themes::SaveBlockPattern` / `DeleteBlockPattern` services + an
`Admin::BlockPatternsController` (`index`/`create`/`destroy`) reusing
`SaveBlockLayout`'s `-customizations` redirect; client-side a `patterns.js` service,
a "Save as pattern" button in `block-toolbar.gjs`, a third `Patterns` left-rail tab
in `shell.gjs` with a `patterns-panel.gjs` (modeled on `palette-panel.gjs`), and a
new `wf-palette-pattern` drag type whose drop clones the subtree in with fresh
stable keys. Capture/insert reuse `serializeEntryForSave` / `cloneLayoutForDraft`
from `lib/mutate-layout.js`.

**Why deferred**: exploring code-defined composite blocks first — that exploration
may reshape how a "saved composition" is represented, so patterns shouldn't be built
until that lands.

## Other items (add here as they come up)

### Editor chrome revamp — deferred from Phase 6 (the final phase)

Phase 6 tokenized the on-canvas chrome and gave the two `role="toolbar"` surfaces
(block toolbar, activity bar) a roving tabindex. These were intentionally left
out and can be picked up later:

- **Floating "+" inserter** on the canvas — a hover/selection affordance to
  insert a block beside the current one without the palette. Deliberately not
  built (kept the existing reveal model).
- **On-canvas grid-cell arrow-nav** — arrow-key movement between grid cells
  while a grid is selected.
- **Keyboard resize for the span / track handles** — the resize handles are
  pointer-only; no keyboard equivalent yet.
- **Inspector rich-text toolbar semantics** — the inspector's inline-format
  controls aren't yet a roving toolbar like the canvas one.
- **Keyboard focus landing after a structural mutation** (move and delete) — when
  a reorder disables the just-used arrow at a list edge, or a delete removes the
  focused block, DOM focus drops to `<body>`. Restoring it needs a focus
  coordinator that survives the chrome re-render (an instance-local restore
  doesn't hold because the affected node is replaced / the toolbar can re-mount).
  Move and delete share this; do them together.
- **Alt+F10-style toolbar entry during a live ProseMirror session** — while an
  inline text session is open, the format buttons stay mouse/shortcut-only (Tab
  ends the session). `Mod-b` / `Mod-i` / `Mod-k` are the keyboard parity; a way
  to jump into the toolbar mid-session is not built.
