# Things to revisit

Open questions and deferred work for the visual editor plugin. Each
entry: what, why deferred, and what'd unblock it.

## Editor-only CSS actually shipping only to staff

**Status**: ⚠️ Open for CSS. ✅ Resolved for JS (commit `500978517cd`).

**What**: The plugin's editor-only **CSS** still ships to every user
on every page. The editor-only **JS** was migrated to the gated admin
bundle: every editor service, modifier, chrome component, and
editor-only lib helper now lives under
`plugins/discourse-visual-editor/admin/assets/javascripts/` and only
downloads when `staff?` is true.

The CSS is split into `visual-editor.scss` (universal block content)
and `admin/visual-editor-chrome.scss` (editor chrome) for
**organization only** — both files load for every user.

**Why CSS is deferred**: Discourse's plugin **stylesheet** pipeline
doesn't expose a per-asset staff gate, while the **JS** pipeline does.

- `register_asset` (`lib/plugin/instance.rb:783`) routes stylesheets by
  `:mobile` / `:desktop` / `:color_definitions` only. There's no
  `:admin` or `:staff` flag, and the `stylesheets/admin/` path
  convention is purely organizational —
  `lib/discourse_plugin_registry.rb:188-211` does not switch on path.
- Plugin stylesheets are injected via `Discourse.find_plugin_css_assets`
  (`lib/discourse.rb:432`) and
  `app/views/common/_discourse_stylesheet.html.erb` lines 21-37 — those
  filter by mobile/desktop only, not by user permission.
- The `:admin` bundle in core (`_discourse_stylesheet.html.erb:12-14`)
  IS gated by `if staff?`, but that's for core's own
  `app/assets/stylesheets/admin.scss`, not for plugin stylesheets.
- `register_asset_filter` exists (`lib/plugin/instance.rb:756`) but
  filters the ENTIRE plugin's asset set — too coarse for our per-file
  need.
- For comparison, the JS side already worked: files under
  `admin/assets/javascripts/` are auto-detected by
  `Plugin::JsManager.admin_js_asset_exists?`
  (`lib/plugin/js_manager.rb:13-16`), compiled as a separate `:admin`
  entrypoint, included via `include_admin_asset: staff?` in
  `app/views/layouts/application.html.erb:28`. The CSS side needs a
  parallel mechanism.

**What'd unblock CSS**:

1. **Core change**: either
   - Add an `:admin` (or `:staff`) flag to `register_asset` for CSS
     that routes to a staff-gated bundle, or
   - Match the JS-side convention: auto-detect files under
     `admin/assets/stylesheets/` and emit them only for staff via a
     parallel `discourse_stylesheet_link_tag(:plugin_admin, ...)`
     block in `_discourse_stylesheet.html.erb`.
2. **Plan B (no core change)**: ship the editor chrome CSS via
   JS-injected `<style>` element on `VisualEditorService.enter()`,
   removed on `exit()`. Plumbing precedent in
   `frontend/discourse/app/instance-initializers/current-user-mention-css.js`.
   Loses SCSS preprocessing — the chrome SCSS would need to live as a
   JS template literal or go through a build-time transform.

**Action**: check with the team whether core can grow a real per-asset
staff gate for plugin CSS. If yes, adopt. If no, plan B is the runtime
injection.

## Per-arg responsive overrides

**Status**: ⚠️ Deferred. Foundation exists (`@container` rules on
`ve:layout` collapse grid/row layouts at <40rem); per-arg **content**
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
also viewport-based for per-arg content. Our `ve:layout` container
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
- **Pilot block**: `ve-heading.text` — smallest, most-edited field.
  After it works there, opt in `ve-paragraph.text`,
  `ve-cta-banner.title`, `ve-media-card.title`, etc.

**What'd unblock**: clear author demand for per-arg content variation
that can't be expressed via `viewport` conditions on alternating
blocks. Reasonable triggers: a theme author asks for it; we see
authors building duplicate blocks just to vary content; the editor's
own demo content needs it.

## Other items (add here as they come up)

_None yet._
