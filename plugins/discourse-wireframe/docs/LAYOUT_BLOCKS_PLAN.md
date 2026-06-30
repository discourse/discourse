# Plan: Close the layout-block coverage gaps + the editor support to author them

## Context

A survey of ~600 themes/components in `~/discourse/all-the/` catalogued the layout patterns the
Discourse community actually builds (heroes, card grids, carousels, footers, stat banners, link
bars, multi-block sidebars). Measured against the current block set's *real feature surface* (not
just block names), ~5 of 11 representative layouts can't be reproduced at all today and ~5 only
partially. The blockers are a mix of missing block types AND missing capabilities: no full-bleed
background+overlay container, no whole-container link, no responsive card reflow, no carousel, no
link-list/stats, no data sources beyond topics — and, on the editor side, no way to author repeated
content well.

This plan closes those gaps end to end: the new live-render blocks (core) **and** the editor support
to author them (plugin), including rich carousels and full drag-and-drop inside the inspector. The
goal stated by the owner: *our block set + editor must be good enough to generate all these layouts
visually.*

The plan extends the existing wireframe planning corpus (`docs/PLAN.md` phased rollout,
`RESPONSIVE_AND_TOKENS_PLAN.md`, `SLOT_BLOCKS_PLAN.md`'s "a slot IS an entry" philosophy,
`REVISIT.md` deferrals). It does not reinvent them.

## Decisions locked (with the owner)

- **Hybrid modeling.** Uniform scalar lists → array-of-object args + a new repeatable inspector
  control. Rich/heterogeneous content → child blocks. (Both competing design passes converged here.)
- **All gap blocks**, nothing deferred.
- **Rich carousels.** A carousel's slides are arbitrary blocks (a slide can be a hero or a CTA).
- **Full DnD in the inspector** for managing children/items, not just the canvas/outline.
- **Full-polish editor affordances** (outline compaction, bulk ops, multi-select, paste-array).
- **Location:** live-render blocks ship in **core** `frontend/discourse/app/blocks/builtin/`; editor
  support ships in the **plugin** `plugins/discourse-wireframe/admin/...`. Core block code never names
  the editor, plugin UI jargon, `wf:*` blocks, or libraries — describe by mechanism.

## Verified design corrections (from adversarial review — folded in)

1. **Whole-container/whole-card link uses a stretched-link `::after` pattern, NOT an `<a>` wrapper.**
   Wrapping children in `<a>` makes invalid nested anchors when a child is itself a link, and conflicts
   with composite `parts` (supplying `children` bypasses composition, `lib/blocks/-internals/composite.js:1-30`).
   A positioned `::after` over one designated link keeps inner links/buttons clickable.
2. **Auto-fit reflow ships as a new `layout` mode `"auto-grid"`, NOT a separate block.** It is
   incompatible with explicit cell placement (an indeterminate width-decided column count breaks
   `grid-column` placements and the `decideGridDrop` chokepoint, which assumes a known column count).
   So `auto-grid` is placement-free: it uses CSS `repeat(auto-fit, minmax(var(--min), 1fr))`, declares
   no per-child `containerArgs.grid`, and in the editor behaves like `stack`/`row` (normal "inside" drop
   zone — `showsInsideDropZone` is true for non-grid modes; no cell overlay, no span-resize). The grid
   overlay stays gated to `mode === "grid"`. Zero impact on the placement machinery.
3. **`carousel` does NOT reuse `ImageCarousel`** — that component is image-locked (`item.element`,
   `@data.items`, `image-carousel.gjs:110,190`). Build a small new core `carousel-track` (scroll-snap +
   dots + keyboard, reusing `lib/swipe-events.js`).
4. **`tag-banner` is route-driven, mirroring `category-banner`** which reads `router.currentRoute.params`
   directly (NOT a data hook — `category-banner.gjs:81,196`). The `fetch-tags` utility instead feeds the
   separate `featured-tags` list block.
5. **Confirmed sound:** `EDIT_PRESENTATION` ambient capability is reactive + precedented
   (`GHOST_BLOCKS`/`EVAL_CONTEXT`, read on the live path at `block-outlet-root-container.gjs:216`);
   block registration is one `builtin/index.js` entry (`freeze-block-registry.js:35-54`); the upload-GC
   walker already recurses nested children (`lib/block_layout_uploads.rb:36-48`, tested 6 levels deep);
   rich-inline inline editing works for new leaves via `RichTextRenderer` markers; container reactivity
   scales (`entry-processing.js`, `createBlockArgsWithReactiveGetters`).

---

## Modeling tracks — which block uses what

| Block | Track | Items / children |
|---|---|---|
| `link-list` | **array** + repeatable control | `items: [{label,url,icon}]` |
| `stats` | **array** + repeatable control | `items: [{value,label,icon,href}]` |
| `section`/`hero` | **children** | overlay = heading/paragraph/button-link children |
| `card` | **children** (composite `parts`) | image/title/meta/body parts |
| `layout` — new **Tiles** mode | **children** (flow container) | `card` (or any) children; auto-fit reflow (a "card grid" = `layout` in Tiles mode of cards) |
| `carousel` | **children** (rich slides) | arbitrary blocks as slides (hero/cta/card/…) |
| `embed` | leaf | cooked HTML |
| `tag-banner` | leaf (route-driven) | — |
| `featured-users` / `featured-tags` / `recent-posts` | leaf (data hook) | server-fetched |
| `list` | **array** + repeatable control | ordered/unordered; `items:[{content}]` |
| `tabs` + `tab` | **children** (collapsing family) | tab panels of arbitrary blocks |
| `accordion` + `accordion-item` | **children** (collapsing family) | collapsible sections of arbitrary blocks |
| `table` | **structured 2D** (shares grid infra) | cells hold arbitrary blocks (one entry/cell; container for multi-block); placement via `containerArgs.grid` |
| `quote` | leaf | testimonial: content + attribution + optional avatar |
| `icon` | leaf | standalone icon (size / color / optional link) |
| `video` | leaf | upload/iframe video (poster / loop / controls) |

The **collapsing-container family** (`carousel`, `tabs`, `accordion`) all share one editor mechanism: live shows a
subset (one slide / active tab / open sections), the editor reaches all of it via `EDIT_PRESENTATION` + paged/expanded
in-place editing (§4h). They're built once as a pattern, not three times.

---

## 1. New blocks — full specs

All live blocks are CORE under `frontend/discourse/app/blocks/builtin/`, exported from `builtin/index.js`.
Schemas use only existing arg types/controls except the new `array itemType:"object"` (§3). Patterns are
copied from `media-card.gjs` (backdrop + `data-block-arg` markers), `layout.gjs` (container + childArgs +
container-query collapse), `featured-topics.gjs`/`recent-topics.gjs` (data hook), `composite.js` (parts).

### 1a. `section` / `hero` — container (children overlay)
- **args:** `background{image, allowDark, defaultFit:"cover"}`, `backgroundColor{color}`, `gradient{string}`,
  `overlayColor{color}`, `overlayOpacity{number 0–1}`, `minHeight{string}`, `contentAlign{enum start/center/end}`,
  `contentWidth{enum contained/wide/full}`, `href{url}` (stretched-link).
- **childArgs:** optional `stack` namespace (alignSelf, flexGrow) mirroring `layout`.
- **render:** `<section>` with `background-image` custom props (light/dark) lifted from `media-card.gjs:129-186`
  + `data-block-arg="background"` `data-drop-fills-block`; `__overlay` tint div; `__content` renders `{{#each @children}}`.
  Stretched-link = `::after` over content when `@href` set.

### 1b. `card` — container via composite `parts`
- **args (shell):** `href{url}` (stretched-link, rendered as a sibling `::after`, not a wrapper), `variant{enum vertical/horizontal}`, `background{color}`.
- **parts:** `[{id:"image",block:"image"},{id:"title",block:"heading",args:{level:3},lock:["level"]},{id:"meta",block:"paragraph"},{id:"body",block:"paragraph"}]`.
  Instance overrides ride the path-keyed scheme (`composite.js`). When an entry supplies its own `children`, composition is bypassed → free-form card.

### 1c. Grids → `layout` modes (no separate block)
Explicit grids keep `layout` `mode:"grid"` (existing: fixed columns, per-child cell placement, overlay + span-resize).
Reflowing card grids use a NEW `layout` mode, **Tiles**:
- **new args on `layout`:** `minItemWidth{string default "16rem"}` (+ existing `gap`/`align`).
- **render:** `display:grid; grid-template-columns: repeat(auto-fit, minmax(var(--min), 1fr))` via custom props.
  Placement-free — no per-child `containerArgs.grid`; children flow in document order and reflow by container width.
- A "card grid" is simply a `layout` in Tiles mode whose children are `card` blocks. Edited **on the canvas** (§3), no list.

### 1d. `link-list` — leaf (array items)
- **args:** `layout{enum vertical/horizontal}`, `gap`, `align`, `items{array itemType:"object", itemSchema:{label{string,required}, url{string,url,required}, icon{string,icon}}}`.
- **render:** `<nav><ul>{{#each @items}}<li><a href>{{icon}}{{label}}</a></li>{{/each}}</ul></nav>`.

### 1e. `stats` — leaf (array items)
- **args:** `columns{number}`, `gap`, `align`, `items{array itemType:"object", itemSchema:{value{string,required}, label{string,required}, icon{string,icon}, href{string,url}}}`.

### 1f. `carousel` — container (rich slides)
- **args:** `showDots{boolean}`, `loop{boolean}`, `autoplay{number sec, 0=off}`, `perView{number}`, `aspectRatio{string}`.
- **slides are children** (any block). Live: renders via the new `carousel-track` (one/`perView` slide(s) + dots/arrows).
  Editor: stays the real paged track (autoplay paused); its prev/next/dots stay interactive so the author **slides to any
  slide and edits it in place** on the canvas (the visible slide is a normal child chrome). Complemented by the inspector
  slide-manager (§3) for reorder/add/remove + jump-to-slide, and an optional "expand all" overview that stacks every slide
  for bulk reordering. Driven by `EDIT_PRESENTATION` (§4c).

### 1g. `embed` — leaf (cooked HTML)
- **args:** `html{string, code control}` (pre-cooked/oneboxed), `url{string,url}`, `aspectRatio`.
- **render:** `DDecoratedHtml @html={{trustHTML html}}` (XSS-safe: server cooker sanitizes; `d-decorated-html.gjs:157-173`
  throws unless htmlSafe) or `DCookText @rawText={{url}}` for a URL to onebox.

### 1h. `tag-banner` — leaf (route-driven)
- Mirrors `category-banner.gjs`: reads the current tag from `router.currentRoute.params`, renders nothing off-route.
  Uses `dDiscourseTag` for the tag chrome. **No data hook.**

### 1i. `featured-users` / `featured-tags` / `recent-posts` — leaf data blocks
- Mirror `featured-topics`/`recent-topics`: declare `data:{request,resolve,skeleton}`; resolve via the new
  fetch utilities (§4e). Render with `DUserAvatar`/`DUserLink` (users), `dDiscourseTag`/`tag-list` (tags),
  a basic post list (posts). Each exports a `VALID_*` filter/sort enum for its `filter` arg.

### 1j. `list` — leaf (array items), ordered/unordered
- **args:** `ordered{boolean}`, `items{array itemType:"object", itemSchema:{content:richInline}}`.
- **Array track** → reuses the repeatable inspector control (§2); item text in-place-editable on canvas.
- **render:** `<ol>`/`<ul>` of `<li>` rich-inline. Nested lists (sub-lists) → a children variant; defer the nesting affordance, ship flat lists first.

### 1k. `tabs` + `tab` — container (collapsing family, §4h)
- `tabs` (container): children are `tab` blocks; arg `align{enum}` for the tab strip.
- `tab` (container): `label{richInline}` arg + its own children content (any blocks).
- **Live:** a tab strip + the active tab's panel. **Editor:** paged-in-place — click a tab to make it active and edit its
  panel where it sits (EDIT_PRESENTATION pauses any auto behavior; tab strip clickable via the chrome nav exemption);
  optional "expand all" shows every panel stacked. New tabs added via palette-drop / duplicate / the slide-manager-style list reused for tabs.

### 1l. `accordion` + `accordion-item` — container (collapsing family, §4h)
- `accordion` (container): children are `accordion-item`; arg `allowMultiple{boolean}` (one-open vs many-open).
- `accordion-item` (container): `title{richInline}` + `defaultOpen{boolean}` + children content.
- **Live:** sections expand/collapse. **Editor:** EDIT_PRESENTATION renders all items open so each panel's children are editable in place; toggling an item in the editor just previews collapse.

### 1m. `table` — structured 2D block (cells hold arbitrary blocks)
- **Model:** a `table` is a constrained 2D grid; each cell is a child entry placed via `containerArgs.grid = {column,row}`
  — the SAME shape as `layout` grid. A cell holds **one** entry; for arbitrary/multiple blocks in a cell, place a container
  (`group`/`section`) there (containers-in-cells already work — verified; no nesting limit beyond the global block depth).
- **Reuses the grid infrastructure (verified, see §4i):** the pure placement layer (`grid-placement.js` — parseTrack/
  gridDimensions/normalizeFractions), the `decideGridDrop` chokepoint + `GridManipulator`, the `grid-overlay.gjs` cell
  placeholders + drop preview, and the span-resize handles. Cell spans (`column:"1 / 3"`) map directly to `colspan`/`rowspan`
  at render. Opt-in via a new block-metadata capability `gridEditable` (§4i) — no reinventing 2D editing.
- **Table-specific (NOT shared):** semantic `<table>/<tr>/<td>` render with `<th scope>` header row/column (a11y); a **dense
  M×N matrix** invariant (every cell exists, no sparse holes — unlike `layout` grid's free placement); colspan/rowspan derived
  from grid spans at render; no `mode`/`columnFractions`/`autoCollapse`. Adds validation for the dense matrix + headers.
- **args:** `columns{number}`, `rows{number}`, `headerRow{boolean}`, `headerColumn{boolean}`. **childArgs:** `grid{column,row,align,justify}` (reused from `layout`).
- **Editor:** the shared grid overlay (cells, drag-into-cell, span-resize) over a semantic table; click a cell's content to
  edit it (it's a normal child chrome); add/remove row/column grows/shrinks declared dims through the chokepoint. **Invariant
  to preserve:** all table drops route through `decideGridDrop` (the sole chokepoint) — no ad-hoc placement (matches the
  existing "no service method places into a grid" guard).

### 1n. `quote` — leaf (testimonial)
- **args:** `content{richInline, required}`, `attribution{richInline}`, `role{richInline}`, `avatar{image, allowDark, aspectRatio:1}`.
- **reuses** `RichTextRenderer` (all text, in-place-editable) + `DLightDarkImg` (avatar). **render:** `<figure><blockquote>{content}</blockquote><figcaption>` avatar + attribution + role `</figcaption></figure>`.

### 1o. `icon` — leaf (standalone)
- **args:** `icon{string, icon control, required}`, `size{enum sm/md/lg}`, `color{color}`, `href{url}` (stretched-link or `<a>`).
- **reuses** `dIcon`. **render:** `<span>`/`<a>` wrapping the icon; honors the `data-block-arg="icon"` rich-text marker.

### 1p. `video` — leaf
- **args:** `source{string url/upload, required}`, `poster{image}`, `autoplay{boolean default false}`, `loop{boolean}`, `muted{boolean}`, `controls{boolean default true}`, `aspectRatio{string}`.
- **render:** native `<video>` for uploads/direct files; `<iframe>` for known providers. **Complements `embed`:** `video` = a
  direct file/iframe with native controls + poster; `embed` = onebox/cooked HTML for social/provider links. Author picks `embed`
  for "paste a link", `video` for "host/point at a video file".

---

## 2. Centerpiece A — the repeatable inspector control (array track)

For `link-list` / `stats`. Three touch points + one new component, all on the existing schema→FormKit pipeline.

**Core schema extension** (`frontend/discourse/app/lib/blocks/-internals/validation/args.js`):
- Add `"object"` to `VALID_ITEM_TYPES`; add `itemSchema` to `VALID_ARG_SCHEMA_PROPERTIES` (+ a `SCHEMA_PROPERTY_RULES`
  entry, `allowedTypes:["array"]`).
- In schema validation, when `type:"array" && itemType:"object"`, require `itemSchema` and recurse each sub-field
  through the existing `validateArgSchemaEntry` (the same recursion `type:"object"`/`properties` already uses).
- In `validateArgValue` array branch, validate each element against `{type:"object", properties:itemSchema}` →
  **per-item indexed error paths** (`items[2].url`) for free.
- `decorator.js` JSDoc documents `itemSchema` by mechanism only ("a consumer renders a repeated mini-form"); no editor jargon.

**Plugin control:**
- `lib/schema-to-fields.js:83-87` — `itemType:"object"` → control `"repeatable"`.
- `components/editor/inspector-field.gjs:24-56` — register `repeatable:"custom"` + a branch mounting `InspectorRepeatableField`, passing `@field.schema` (carries `itemSchema`).
- **NEW `components/editor/inspector-repeatable-field.gjs`** — modeled on `inspector-image-field.gjs` (live read/write
  through the wireframe service, not FormKit draft). Each row renders its sub-fields by calling
  `schemaToFields(itemSchema)` **recursively** → sub-fields get the right controls (url/icon/image/text) automatically.
  Rows collapse to a summary line; **drag handle reorders rows** (§ DnD below); add seeds from sub-field defaults;
  remove splices; every change writes the whole array via `updateSelectedArg`. Indexed errors route to the offending row.
  Includes **paste-array** (JSON/CSV bulk import) — full-polish affordance lands here.
- **Hard part flagged:** an `image` sub-field — `InspectorImageField` writes the top-level arg via `setImageArg`; embedded
  in an array item it must write `entry.args.items[i].image`. Generalize `setImageArg` to accept a path, or intercept in
  the repeatable control. (link-list/stats don't use image sub-fields in v1, so this is only needed if an array block later does.)

## 3. Centerpiece B — editing surfaces (canvas-first WYSIWYG)

The editor is WYSIWYG: children-track content is manipulated **directly on the canvas** as the real blocks, never as
an abstract list in the inspector. The inspector only ever shows the *selected block's own* fields.

**Canvas + outline (all children-track blocks: hero overlay, card parts, Tiles-mode cards, carousel slides):**
- **Add** → drag a block from the palette onto the container on the canvas; or duplicate an existing child.
- **Reorder** → drag the real block on the canvas (existing sibling drop zones, `block-chrome.gjs`); the outline tree
  stays as the existing structural navigator + alternative drag surface.
- **Edit** → select on canvas → inline text edit (rich-inline) + icon/url popovers + the block's own inspector fields.
- **Remove** → the block's chrome delete; multi-select + bulk delete for cleanup (§5).
All of this is existing machinery (chrome, dnd, outline, palette, `moveBlock`/`insertBlock`/`removeBlock`,
`duplicateBlock` at `wireframe.js:1121`). Minimal new editor code.

**Grid / Tiles modes are canvas-only — no inspector list.** `grid` mode keeps its cell overlay + span-resize; `Tiles`
mode reflows the real cards live and authors drag/drop/select them directly (normal "inside" drop zone). The new mode
is edited visually, not via any list representation.

**Carousel — paged-in-place editing on the canvas (primary).** In edit mode the carousel stays its real paged track
(autoplay paused, `EDIT_PRESENTATION` §4c); its prev/next/dots stay interactive so the author **slides to any slide and
edits it directly where it sits** (the visible slide is a normal child chrome — select, inline-edit, drag-reorder). This
is the WYSIWYG slide-editing you asked for. An optional **"expand all" overview** stacks every slide for bulk reordering.

**Carousel slide-manager (inspector, opt-in complement).** Because slides hide on the live page, a carousel — and *only*
a carousel — also gets an optional inspector slide list (the "full DnD in the inspector" you asked for earlier):
- **NEW `components/editor/inspector-carousel-slides.gjs`** — one row per slide (thumbnail + label), DnD reorder + add
  (block picker: a slide can be a hero/cta/card/any block) + remove. Reuses the outline's dnd primitives
  (`dDragAndDropSource`/`dDragAndDropTarget`, `outline-panel.gjs:703-716`) and the existing `moveBlock`/`insertBlock`/
  `removeBlock` mutations — no new mutation logic. **Clicking a row pages the canvas to that slide and selects it**, so the
  list and the paged-in-place canvas editing stay in sync. NOT a generic children manager forced on every container.

## 4. Cross-cutting capabilities

### 4a. Stretched-link (whole-container/card link)
Core CSS utility `.d-block-stretched-link` (a positioned `::after` over the block). Blocks that take an `href`
(`section`, `card`) render a designated stretched link instead of wrapping children. Chrome already intercepts
clicks in edit mode (`block-chrome.gjs onClick` `preventDefault`+`stopPropagation`), so editing isn't broken.

### 4b. `layout` Tiles mode (auto-fit reflow)
Per correction #2 — a new placement-free `layout` mode, **Tiles**: auto-fit CSS, `minItemWidth` arg,
normal "inside" drop zone, no overlay/span-resize. Edited canvas-only WYSIWYG (drag real cards, drop from palette,
select to edit) — no inspector list. The grid overlay stays gated to `mode === "grid"` (`block-chrome.gjs:340`).

### 4c. `EDIT_PRESENTATION` ambient capability (edit-mode carousel behavior)
- Core: add `EDIT_PRESENTATION:"editPresentation"` to `DEBUG_CALLBACK` in `lib/blocks/-internals/debug-hooks.js`
  + a reactive getter (reads the `trackedMap`, like `GHOST_BLOCKS`/`EVAL_CONTEXT`). JSDoc by mechanism only ("when set,
  a paged/collapsing container should make all of its content reachable for editing").
- Plugin: install it alongside the existing installers in `api-initializers/wireframe.js` (`() => editor.isActive`,
  same save-and-OR pattern as `GHOST_BLOCKS` at `:98-106`).
- The **collapsing family** (`carousel`, `tabs`, `accordion`, §4h) reads it to switch into edit behavior: carousel pauses
  autoplay + keeps manual paging so the visible slide is editable in place; tabs keep the strip clickable to switch the
  editable panel; accordion opens all items. Plus an optional "expand all" overview. Live (flag unset) = normal paged/collapsed render.
- **Chrome exemption:** these nav controls (prev/next/dots, tab strip, item toggles) must stay clickable in edit mode (`block-chrome.gjs onClick`
  otherwise swallows clicks via `preventDefault`/`stopPropagation`). Mark the nav controls with a data-attr the chrome
  lets through, so paging works while the carousel block itself stays selectable.

### 4d. New core `carousel-track` component
`frontend/discourse/app/components/` (or `lib/blocks/-internals/`). Scroll-snap track + dots + prev/next + keyboard,
reusing `lib/swipe-events.js`. Hosts **arbitrary slide content** (yielded), unlike image-locked `ImageCarousel`.

### 4e. Data utilities (mirror `fetch-topic-list.js`)
New CORE files in `lib/blocks/-internals/`, each a pure async resolver used from a block's `data.resolve({owner,signal})`:
- `fetch-users.js` → `owner.lookup("service:store").findAll("directoryItem", {...})` (top contributors).
- `fetch-tags.js` → `store.findAll("tag")` sorted/sliced (popular tags).
- `fetch-posts.js` → UserPostsStream pattern (recent posts/replies).
Each exports a `VALID_*` enum for the consuming block's `filter`/`order` arg.

### 4f. Responsive
The `layout` Tiles mode auto-fit covers the surveyed card-reflow need now. Per-breakpoint column overrides stay on the
existing `RESPONSIVE_AND_TOKENS_PLAN` track (container-query collapse already ships on `layout`); not duplicated here.

### 4h. Collapsing-containers family (`carousel`, `tabs`, `accordion`)
All three hide part of their content on the live page (one slide / one active tab / collapsed sections) and must expose
all of it for editing. Build the pattern ONCE:
- They read `EDIT_PRESENTATION` (§4c) to switch into edit behavior: pause auto behavior, keep their navigation
  (dots/arrows, tab strip, item toggles) interactive, and edit the currently-shown child **in place** on the canvas.
- An optional **"expand all" overview** renders every child stacked for bulk reorder.
- Their nav controls share the same **chrome click-exemption** (a data-attr `block-chrome.gjs onClick` lets through), so
  paging/tab-switching/toggling works while the container stays selectable.
- Their per-child label/title (slide none, tab `label`, accordion `title`) is a normal arg on the child block, edited inline.
This keeps one mental model and one code path for the whole family; new collapsing blocks later cost almost nothing.

### 4i. Generalize grid-editing to a capability (`gridEditable`) — lets `table` share the grid infra
The pure grid layer is already block-agnostic: `grid-placement.js`, `grid-drop.js`/`decideGridDrop`, `grid-math.js`,
`grid-overlay.gjs`, `GridManipulator`, and the span-resize handles all operate on any entry with `containerArgs.grid`. The
editor only hardcodes `blockName === "layout"` in a few gating spots; generalize those to a `@block` metadata flag
`gridEditable: true` so any block (here, `table`) can opt into cell placement. Call sites to change (verified):
- `wireframe.js` `isGridContainer()` (~`:4511`) — the `blockName !== "layout"` guard → also accept `gridEditable` blocks.
- `block-chrome.gjs` `isGridLayout` (`:341-352`), which feeds `showsGridOverlay` (`:426`), `showsInsideDropZone` (`:578`), `isEmptyContainer` (`:667`).
- `outline-panel.gjs:477` grid-mode display.
`grid-overlay.gjs`, `grid-manipulator.js` (beyond that guard), `grid-placement.js`, `grid-drop.js` need no change — already agnostic.
This also removes `layout`'s own name-hardcoding (a net simplification). **`layout` Tiles mode does NOT set the flag** — it
stays placement-free flow layout; only placement-grid blocks (`layout` grid mode, `table`) are `gridEditable`. The
generalization MUST preserve the `decideGridDrop` sole-chokepoint invariant and keep the existing grid invariant tests green.

## 5. Editor support summary (per surface)

- **Array items (link-list/stats):** the inspector **repeatable control** is their structural editor (add/remove/reorder
  rows, recursive sub-fields, paste-array) — §2; item *text* is also in-place-editable on the canvas for a WYSIWYG feel.
- **Children-track structure (hero, card, Tiles cards, slides):** **canvas + outline** — WYSIWYG, no inspector list (§3).
- **Carousel:** canvas (all slides via `EDIT_PRESENTATION`) **plus** the opt-in inspector slide-manager DnD list (§3).
- **Scale affordances** (canvas/toolbar/outline, not a list): **bulk duplicate / "repeat ×N"** (`block-toolbar.gjs`),
  **multi-select + bulk delete** (selection-set in `wireframe.js`), copy/paste, and **outline child-count compaction**
  (`outline-panel.gjs`) so a many-child container collapses to a `"link-item × 18"` badge in the navigator.

---

## 6. Completeness checklist — every site a new block touches

Per new builtin block (verified against `media-card`/`featured-categories` wiring):
- **Register:** add export in `frontend/discourse/app/blocks/builtin/index.js` (auto-picked by `freeze-block-registry.js:35-54`).
- **i18n:** keys under `blocks.builtin.<name>.*` in core `config/locales/client.en.yml` (displayName, description, each arg label/helpText/group, placeholders). ~10–20 keys/block.
- **Icons:** the `@block icon` must be a registered icon. `rocket` and `list-ul` are NOT yet registered — pick existing icons or `register_svg_icon` in `plugin.rb` (plugin) / core svg set. `border-none`, `image` exist.
- **SCSS:** one `app/assets/stylesheets/common/blocks/_<name>.scss` + `@import` in `_index.scss`; `.d-block-<name>` BEM.
- **childArgs (containers):** drives the per-child placement inspector (`inspector-container-args-form.gjs`); declare only if needed.
- **allowedOutlets/deniedOutlets:** decide per block (e.g. `tag-banner` likely banner-area outlets).
- **Tests:** core integration `frontend/discourse/tests/integration/components/block-<name>-test.gjs`; plugin unit (`schema-to-fields`, `inspector-repeatable-field`, `inspector-children-manager`) + a system spec per major flow.
- **JSDoc / authoring doc:** keep didactic JSDoc on new files; add examples to `.pending-plans/docs/block-api-authoring.md`.

Shared, once:
- `layout.gjs` new **Tiles** mode (placement-free auto-fit) + `minItemWidth` arg + Tiles SCSS.
- `debug-hooks.js` `EDIT_PRESENTATION` key + getter; installer in `api-initializers/wireframe.js`.
- `block-chrome.gjs` carousel paged-edit handling (pause autoplay, exempt nav controls from click-intercept, optional expand-all); confirm Tiles mode uses the non-grid "inside" drop zone.
- `validation/args.js` `itemType:"object"` + `itemSchema` + recursion + indexed value validation.
- `inspector-field.gjs` `repeatable` control registration; NEW `inspector-repeatable-field.gjs` (array items).
- NEW `inspector-carousel-slides.gjs` (carousel-only slide-manager DnD list).
- `carousel-track.gjs`, `fetch-users.js`, `fetch-tags.js`, `fetch-posts.js`, stretched-link CSS.
- Generalize grid-editing from `blockName === "layout"` to a `gridEditable` metadata capability (§4i): `wireframe.js isGridContainer`, `block-chrome.gjs isGridLayout` + dependents, `outline-panel.gjs:477`. Reused by `table`; keep grid invariant tests green.

## 7. Core/plugin split + no-jargon rule
Live blocks, schema extension, data utilities, carousel-track, EDIT_PRESENTATION key, stretched-link → **core**, all
described by mechanism (no "wireframe"/"inspector"/`wf:*`/library names in comments). Repeatable control, carousel
slide-manager, outline compaction, bulk ops, EDIT_PRESENTATION installer, chrome branches → **plugin** (staff-gated `admin/`).

## 8. Execution phases

Each phase is independently shippable behind the existing `wireframe_enabled` gate, must end green
(`bin/lint --fix`, `bin/qunit`, `bin/rspec`), and has a concrete acceptance demo. **Dependencies:** P1
is a prerequisite for P3 (schema) and P2 (stretched-link); P4 builds the collapsing-family mechanism
once; P5 is self-contained (touches the grid gating); P6/P7 depend only on P1–P2. Spec detail lives in
§1–§4; phases reference it rather than repeat it.

### Phase 1 — Foundations (schema + linkable containers) · core-only, no new palette blocks
- **Build:** array `itemType:"object"` + `itemSchema` + recursive schema validation + per-item indexed value errors (§2); the stretched-link CSS utility (§4a).
- **Files:** `lib/blocks/-internals/validation/args.js` (`VALID_ITEM_TYPES`, `VALID_ARG_SCHEMA_PROPERTIES`, recursion, array value branch), `lib/blocks/-internals/decorator.js` (JSDoc, by mechanism), `app/assets/stylesheets/common/blocks/_index.scss` + a stretched-link partial.
- **Exit:** unit tests — `itemSchema` decoration rejects a bad sub-field; runtime value validation emits `items[0].label` paths; existing arg-validation suite green. No user-facing change.

### Phase 2 — Containers & responsive card grids · unblocks heroes + card grids
- **Build:** `section`/`hero` (§1a); `card` via composite `parts` + stretched-link (§1b); `layout` **Tiles** mode + `minItemWidth` (§1c/§4b). All editing canvas-WYSIWYG (§3).
- **Files (core):** `blocks/builtin/section.gjs`, `card.gjs`; edit `blocks/builtin/layout.gjs` (Tiles mode); `builtin/index.js`; per-block SCSS + `_index.scss`; i18n keys; icons (see checklist §6). **(plugin):** confirm `block-chrome.gjs` Tiles uses the non-grid "inside" drop zone (no overlay/span-resize).
- **Reuse:** `media-card.gjs` backdrop pattern, `composite.js` parts, `DLightDarkImg`.
- **Exit:** integration render tests per block; Tiles reflows by container width; demo — build a hero + a Tiles-of-`card`s grid via `api.renderBlocks`, then on the canvas drop a card in, reorder it, and confirm the whole-card link navigates.

### Phase 3 — Array-content blocks + the repeatable control · unblocks footers, nav bars, stat banner, lists
- **Build:** the repeatable inspector control (§2) — recursive sub-fields, add/remove/reorder (DnD rows), indexed-error routing, **paste-array** (JSON/CSV); then `link-list` (§1d), `stats` (§1e), `list` (§1j).
- **Files (plugin):** `lib/schema-to-fields.js` (array→`repeatable`), `components/editor/inspector-field.gjs` (register `repeatable`), NEW `inspector-repeatable-field.gjs`, `inspector-form.gjs` (indexed-error routing). **(core):** `blocks/builtin/link-list.gjs`, `stats.gjs`, `list.gjs` + index/i18n/icons/SCSS.
- **Reuse:** `inspector-image-field.gjs` (control model), `schemaToFields` recursion, `RichTextRenderer` (item text inline-edits on canvas).
- **Exit:** control unit tests; demo — build a 3-column footer (link-lists) + a stat banner + an ordered list; add/reorder/paste rows in the inspector; edit an item's text inline on the canvas.

### Phase 4 — Collapsing-containers family · unblocks carousels, tabs, accordions
- **Build (mechanism, once):** `EDIT_PRESENTATION` capability + installer (§4c); core `carousel-track` (§4d); chrome nav-exemption + paged/expanded-in-place editing (§3/§4h). **(blocks):** `carousel` + opt-in inspector slide-manager (§1f/§3); `tabs`/`tab` (§1k); `accordion`/`accordion-item` (§1l).
- **Files (core):** `lib/blocks/-internals/debug-hooks.js`; NEW `carousel-track.gjs`; `blocks/builtin/carousel.gjs`, `tabs.gjs`, `tab.gjs`, `accordion.gjs`, `accordion-item.gjs` + index/i18n/icons/SCSS. **(plugin):** `api-initializers/wireframe.js` (installer), `block-chrome.gjs` (nav-exemption + paged editing + expand-all), NEW `inspector-carousel-slides.gjs`.
- **Reuse:** `lib/swipe-events.js`; outline dnd primitives + `moveBlock`/`insertBlock`/`removeBlock` for the slide-manager.
- **Exit:** live carousel pages with autoplay; in the editor it pages in place with autoplay off, nav clickable, the visible slide editable; slide-manager reorders via `moveBlock`; tabs switch + edit the active panel; accordion opens all items in the editor; demo a rich carousel whose slides are `hero`/`cta` blocks.

### Phase 5 — Table + grid-editing capability · unblocks tables (self-contained)
- **Build:** generalize grid-editing to a `gridEditable` metadata capability (§4i) — ungate the `blockName === "layout"` checks; then `table` (§1m) **reusing** grid placement + `decideGridDrop` + overlay + span-resize, with semantic `<table>` render, header row/col, dense-matrix validation, arbitrary-block cells (a container per cell).
- **Files (plugin):** `wireframe.js isGridContainer` (~`:4511`), `block-chrome.gjs isGridLayout` (`:341-352`) + dependents, `outline-panel.gjs:477`. **(core):** `blocks/builtin/table.gjs` + index/i18n/icon/SCSS.
- **Reuse (as-is):** `grid-placement.js`, `grid-drop.js`/`decideGridDrop`, `grid-manipulator.js`, `grid-overlay.gjs`.
- **Exit:** existing grid invariant tests (`grid-drop`/`grid-placement`) stay green; `layout` grid mode still works (regression); demo — build a table, drop blocks into cells, span a cell (→ `colspan`/`rowspan`), add/remove a row & column, and put a `group` of multiple blocks in one cell.

### Phase 6 — Data, context & media leaves · sidebar parity, embeds, marketing primitives
- **Build:** data utilities `fetch-users`/`fetch-tags`/`fetch-posts` (§4e) + `featured-users`/`featured-tags`/`recent-posts` (§1i); `embed` (§1g); route-driven `tag-banner` (§1h); `quote` (§1n); `icon` (§1o); `video` (§1p).
- **Files (core):** `lib/blocks/-internals/fetch-users.js`/`fetch-tags.js`/`fetch-posts.js`; `blocks/builtin/{featured-users,featured-tags,recent-posts,embed,tag-banner,quote,icon,video}.gjs` + index/i18n/icons/SCSS.
- **Reuse:** `DUserAvatar`/`DUserLink`, `dDiscourseTag`/`tag-list`, `DDecoratedHtml`/`DCookText`, `DLightDarkImg`, `dIcon`, the `category-banner` route pattern.
- **Exit:** data blocks fetch + render with loading/empty states (pretender tests); `tag-banner` renders only on tag routes; `embed` renders a cooked onebox safely; `quote`/`icon`/`video` render and inline-edit where applicable.

### Phase 7 — Scale polish · children authoring at volume
- **Build:** outline child-count compaction (badge), bulk duplicate / "repeat ×N", multi-select + bulk delete (§5).
- **Files (plugin):** `outline-panel.gjs`, `block-toolbar.gjs`, `wireframe.js` (selection-set).
- **Exit:** a 12-card Tiles grid collapses to a `"card × 12"` badge in the outline; "repeat ×N" adds N copies; multi-select deletes several blocks at once.

## 9. Verification
- Per block: core integration render tests; `schema-to-fields` mapping; `validation/args.js` decoration + runtime (indexed-path errors).
- Repeatable control: unit tests for add/remove/reorder (DnD), recursive sub-field rendering, paste-array, indexed-error routing.
- Carousel: live = paged track (autoplay per arg); in editor `EDIT_PRESENTATION` pauses autoplay + keeps manual paging so the visible slide is editable in place, nav controls stay clickable, and the slide-manager + expand-all overview reorder via `moveBlock`.
- Tiles mode: reflows by container width; Tiles `layout` takes the non-grid "inside" drop zone (no overlay).
- **Reconstruction acceptance test (the real bar):** rebuild three surveyed layouts via `api.renderBlocks` in a scratch initializer — a responsive card grid (`layout` Tiles of cards), a hero, a multi-column footer (link-lists) — and a rich carousel of CTA slides; view light/dark at desktop + mobile widths; confirm reflow, stretched-link nav, and that authoring each in the editor is pleasant.
- System specs (plugin): drag a card into a Tiles `layout` on the canvas; add+reorder carousel slides both on canvas and in the slide-manager; add+reorder+paste link-list items in the repeatable control; whole-card link navigates; save + reload persists.
- Upload GC: confirm images nested in children survive (walker already recurses — `block_layout_uploads_spec.rb:138-152`).
- `bin/lint --fix`, `bin/qunit`, `bin/rspec` per surface.

## 10. Open decisions / risks
- **`prose`/rich-text deliberately excluded.** Its output is fully covered by composition (`heading`+`paragraph`+`list`+`quote`) plus `embed` (cooked markdown/HTML) for flowing content. A prose block would only add a composer-style authoring surface, at the cost of per-element addressability (you can't condition/move/restyle a fragment of an opaque prose blob). `embed` is the long-form escape hatch; compose blocks for structured layout. Revisit only if authors are demonstrably writing articles in the editor and find block-per-paragraph painful.
- **Image sub-field in array items** (§2) — only bites if a future array block needs an image sub-field; `setImageArg` path-generalization is the fix. link-list/stats don't in v1.
- **Carousel reorder surfaces** (paged-in-place canvas, slide-manager list, expand-all overview) must stay consistent; all route through the same `wireframe.moveBlock`/`insertBlock`, so they can't diverge. Clicking a slide-manager row pages the canvas to that slide.
- **`perView` carousel + responsive** — start with 1-per-view + container-query step-down; richer per-breakpoint perView aligns with the responsive track later.
- **Icon registration** — settle the `rocket`/`list-ul` choice early (checklist §6).
- **Table reuses the grid chokepoint** (§1m/§4i) — the `gridEditable` generalization touches `decideGridDrop`'s gating; it must stay the sole placement chokepoint and the grid invariant tests (`grid-drop`/`grid-placement`) must stay green. Table adds constraints the free grid lacks (dense M×N, header row/col); decide whether those are enforced in the table block or as a table-flavored validation pass over the shared decision.

## 11. Critical files
- `frontend/discourse/app/blocks/builtin/index.js` — register new blocks.
- `frontend/discourse/app/lib/blocks/-internals/validation/args.js` — `itemType:"object"` + `itemSchema` + recursion + indexed value validation.
- `frontend/discourse/app/lib/blocks/-internals/debug-hooks.js` — `EDIT_PRESENTATION` key + getter.
- `frontend/discourse/app/lib/blocks/-internals/fetch-topic-list.js` — template for `fetch-users/tags/posts`.
- `frontend/discourse/app/blocks/builtin/media-card.gjs`, `layout.gjs`, `featured-topics.gjs`, `category-banner.gjs`, `lib/blocks/-internals/composite.js` — pattern exemplars.
- `plugins/discourse-wireframe/admin/.../lib/schema-to-fields.js:83-87` — array→repeatable mapping.
- `plugins/discourse-wireframe/admin/.../components/editor/inspector-field.gjs:24-56` — control registry.
- `plugins/discourse-wireframe/admin/.../components/editor/inspector-image-field.gjs` — model for the repeatable control.
- `plugins/discourse-wireframe/admin/.../components/editor/outline-panel.gjs:703-716`, `palette-entry.gjs` — dnd source/target primitives the carousel slide-manager reuses.
- `frontend/discourse/app/blocks/builtin/layout.gjs` + `app/assets/stylesheets/common/blocks/_layout.scss` — new Tiles mode.
- `plugins/discourse-wireframe/admin/.../api-initializers/wireframe.js:98-106` — `EDIT_PRESENTATION` installer (mirror `GHOST_BLOCKS`).
- `plugins/discourse-wireframe/admin/.../components/editor/block-chrome.gjs` — carousel expanded-stack branch; grid gating reference.
- `lib/block_layout_uploads.rb` — confirm nested-children upload GC.
- Grid-infra reuse for `table` (§4i): `frontend/discourse/app/lib/blocks/-internals/grid-placement.js` (pure, reused as-is); `plugins/discourse-wireframe/admin/.../lib/grid-drop.js` (`decideGridDrop` chokepoint, reused) + `grid-manipulator.js`; `components/editor/grid-overlay.gjs` (reused); ungating in `wireframe.js isGridContainer` (~`:4511`), `block-chrome.gjs:341-352`, `outline-panel.gjs:477`.

---

## Implementation status (as built)

**Shipped & green** (live-render blocks, capabilities, all with passing tests):
- Schema/infra: `itemType:"object"` + `itemSchema` (+ indexed validation), stretched-link CSS, `EDIT_PRESENTATION` capability, `gridEditable` block-decorator option, generalized `setArg` service write.
- Blocks: `section`/hero, `card`, `layout` **Tiles** mode, `link-list`, `stats`, `list`, `carousel`, `accordion`/`accordion-item`, `table` (auto-fill + colspan/rowspan + headers), `icon`, `quote`, `video`, `embed`, `featured-tags`, `featured-users`, `tag-banner`.
- Editor: the **repeatable inspector control** (`inspector-repeatable-field.gjs`, array-of-object items, add/remove/reorder + JSON import); `EDIT_PRESENTATION` installer.
- Data utilities: `fetch-tags.js`, `fetch-users.js`.
- Tests green: `args` 239, `section/card/tiles` 4, `array-content` 3, plugin `schemaToFields` 16, `collapsing` 3, `table` 3, `media-leaves` 4, `data-fetchers` 6, regression `block-outlet` 91, `grid-placement` 19, `grid-drop` 27.

**Deferred (tracked, with specific blockers):**
- `tabs`/`tab` — the children model exposes `Component/containerArgs/blockName/key` to a container but NOT the child's `args`, so the parent can't build a tab strip from child labels. Needs a small core capability (expose child labels / a slots API) first.
- Table cell-placement editor UI — the grid overlay is hard-coupled to the `layout` CSS-grid DOM (`.d-block-layout` selector + `gridTemplateColumns`); a `<table>` needs a geometry-based / table-aware overlay. `gridEditable` flag is in place; table is usable via auto-fill meanwhile.
- `recent-posts` — no clean site-wide recent-posts store endpoint; needs a backend decision.
- Editor scale polish (Phase 7): outline child-count compaction, bulk duplicate/repeat, multi-select + bulk delete.
- Live-data integration tests (pretender) for `featured-tags`/`featured-users` and an acceptance test for `tag-banner`; carousel inspector slide-manager + paged-in-place sliding; accordion exclusivity.
