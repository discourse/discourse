# Coming next — Layout blocks remaining work (P4 → P6)

Carried forward from `REMAINING_WORK_PLAN.md`. P1–P3 shipped & green; the P4
tabs work (the "+" add-tab affordance **and** the implicit-layout-per-tab
reframe) also shipped this round. What remains is the rest of P4, then P5 and P6.

The bar set by the shipped work holds: every change ends green (`bin/lint`,
`pnpm build`, `bin/qunit --filter "…"` non-standalone against the dev server,
`pnpm build` to refresh `dist` after editing source), and nothing lands on the
production render path without a passing test.

---

## P4 — Carousel slide-manager, paged-in-place editing, accordion exclusivity

**Why:** rounds out the collapsing-family authoring UX beyond the shipped
EDIT_PRESENTATION expand-all.

**Already shipped (do NOT redo):**
- **Tabs "add tab" strip affordance** — the editor-chrome "+" at the end of the
  tab strip (rendered only under `EDIT_PRESENTATION`) that appends a panel and
  selects it. Shipped as part of the implicit-layout reframe: each tabs panel is
  now a `layout` block (`childBlocks: ["layout"]`), the editor keeps that
  invariant at one mutation chokepoint, tabs render functionally in the editor
  (one active panel, switchable), clicking a tab selects its panel layout, and
  the active tab's label is edited in place.

**Remaining steps**
1. **Inspector slide-manager** (`components/editor/inspector-carousel-slides.gjs`,
   carousel-only): a DnD list of slides (thumbnail + label) reusing the outline's
   dnd primitives (`dDragAndDropSource`/`Target`) + `moveBlock`/`insertBlock`/
   `removeBlock`. Clicking a row selects/pages to that slide.
2. **Paged-in-place editing** (optional): let the carousel page in the editor
   (instead of, or alongside, expand-all). Requires a chrome nav-exemption —
   mark prev/next/dots with a data-attr that `block-chrome.gjs onClick` lets
   through, so paging works while the block stays selectable. (The tabs work
   already established this functional-paging-in-editor pattern; the carousel can
   follow it.)
3. **Accordion exclusivity:** one-open-at-a-time via `<details name="…">`. Needs
   a shared group name on each item — supply it from the `accordion` parent via
   `childArgs` (a `group` namespace) or derive from the parent key. Uses the same
   parent→child plumbing the tabs work exercised.

**Files:** `blocks/builtin/carousel.gjs`, `accordion.gjs`/`accordion-item.gjs`;
`components/editor/inspector-carousel-slides.gjs`, `block-chrome.gjs`.

**Verify:** slide-manager add/remove/reorder routes through `moveBlock` (unit);
accordion exclusive mode opens one at a time (integration); paging works in the
editor (system).

---

## P5 — Table cell-placement editor UI (the grid overlay over a table)

**Why:** the `table` block ships usable via auto-fill, but lacks the cell-precise
placement / span-resize overlay the `layout` grid has.

**Related pending task:** "Editor: ungate grid overlay to honor `gridEditable`"
(the Phase 5 follow-up reverted earlier) is part of this item — re-apply it here
once the overlay is geometry-based.

**The blocker (verified):** the grid overlay is hard-coupled to the `layout`
CSS-grid DOM — `grid-overlay.gjs` queries `.d-block-layout` (`GRID_LAYOUT_SELECTOR`,
~:584) and reads `getComputedStyle().gridTemplateColumns` (~:469) to position
cells. A semantic `<table>` has neither.

**Design decision — make the overlay geometry-based.** Position cells by
measuring the rendered cell elements' rects (works for `<td>` and CSS-grid cells
alike) instead of parsing `gridTemplateColumns`, and select the grid container
by a generic data attribute (e.g. `[data-grid-editable]`) rather than
`.d-block-layout`. Then re-apply the `gridEditable` ungating (`wireframe.js
isGridContainer`, `block-chrome.gjs isGridLayout`). This benefits any future
grid-editable container, not just the table. (Alternative, faster but hackier: a
table-specific overlay, or an edit-mode CSS-grid mirror render.)

**Steps**
1. Refactor `grid-overlay.gjs` cell positioning to be rect/geometry-based;
   replace the `.d-block-layout`-specific selector + `gridTemplateColumns` read.
2. Re-apply the `gridEditable` generalization (the two getters reverted earlier).
3. Keep `decideGridDrop` (`grid-drop.js`) untouched — it's already block-agnostic.

**Files:** `components/editor/grid-overlay.gjs`, `services/wireframe.js`,
`components/editor/block-chrome.gjs`.

**Verify (critical):** `grid-placement` 19 + `grid-drop` 27 stay green (the
chokepoint is unchanged). System/visual spec: the overlay aligns over a `table`'s
cells; drag-into-cell + span-resize produce correct `containerArgs.grid` (→
colspan/rowspan). Highest-risk item — verify visually before shipping.

---

## P6 — `recent-posts` block

**Why:** completes the data-blocks set (sidebar "recent replies").

**The blocker:** no clean site-wide recent-posts store endpoint (unlike
`topicList` / `tag` / `directoryItem`).

**Design decision needed:** confirm or add a source. Investigate `/posts.json`
(the firehose) and whether a `post` store model resolves it; if neither fits, add
a small read-only endpoint (`Service::Base` per `discourse-service-authoring`)
returning the latest posts. Then mirror the topic-list shape.

**Steps**
1. Settle the endpoint (existing vs new).
2. `lib/blocks/-internals/fetch-posts.js` mirroring `fetch-topic-list.js`.
3. `blocks/builtin/recent-posts.gjs` via the `data` hook + `<@Data>` boundary;
   register/SCSS/i18n.

**Files:** (server, if new) `app/services/…`, controller/route; (client)
`lib/blocks/-internals/fetch-posts.js`, `blocks/builtin/recent-posts.gjs`,
`index.js`, SCSS, i18n.

**Verify:** unit `fetch-posts` (mock store); pretender integration for the block;
request spec if a new endpoint is added.

---

## Sequencing summary

1. **P4** carousel slide-manager + paged-in-place + accordion exclusivity (the
   tabs piece already shipped; this finishes the collapsing family).
2. **P5** table cell-placement overlay (highest risk — geometry-based overlay
   refactor + visual verification; keep the grid chokepoint tests green; folds in
   the reverted `gridEditable` ungating task).
3. **P6** `recent-posts` (gated on a backend endpoint decision).
