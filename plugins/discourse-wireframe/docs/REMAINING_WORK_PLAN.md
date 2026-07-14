# Layout blocks — remaining work plan

Follow-up plan for the items deferred from the layout-blocks build (see
`LAYOUT_BLOCKS_PLAN.md` for the full design + "Implementation status (as built)"
for what already shipped green). Each item below is independently shippable and
ordered by recommended sequence (dependency + value + risk).

The bar set by the shipped work holds: every change ends green
(`bin/lint`, `pnpm build`, `bin/qunit --filter "…"` non-standalone against the
dev server, `pnpm build` to refresh `dist` after editing source), and nothing
lands on the production render path without a passing test.

---

## P1 — `tabs` block — ✅ SHIPPED

**Status:** Done & green. Built as a single `tabs` container (no `tab` block);
panels are arbitrary children. Tab labels live in each child's
`containerArgs.tab.label` (the parent-readable channel — no core capability was
added, since `containerArgs` already carries per-child metadata). Labels are
inline-edited on the strip via a third in-place text target type
(`#containerArgContext` in `wireframe-inplace-text.js`, mirroring the composite-part
path). Editor reuses `EDIT_PRESENTATION` to stack all panels. See
`blocks/builtin/tabs.gjs` + the inline-edit extension.

**Follow-up (deferred — see P4):** the tab strip has no standing "add tab"
affordance. A new panel is added via the generic container flow (drag a block
in, or duplicate an existing panel, then rename inline). For a tabbed UI a "+"
at the end of the strip is the expected gesture; captured under P4.

**Original framing (kept for context):** `tabs` is the one surveyed primitive
still missing, and the capability it needs (a container reading its children's
labels) is small, reusable, and also unblocks accordion exclusivity (P4) and
richer outline rows.

**The blocker (verified):** a container receives each child as a
`ChildBlockResult` carrying `Component` / `containerArgs` / `blockName` / `key`
— but NOT the child's own `args` (`lib/blocks/-internals/entry-processing.js`
builds the result; `args` is in the cache at ~:120 but not surfaced on the
result). So `tabs` can't read each `tab`'s `label` to build the tab strip.

**Design decision — expose child `args` (read-only) on `ChildBlockResult`.**
The data already exists in the cache; surface it on the result object and
document that containers treat it as read-only display metadata (never mutate;
mutation still goes through the normal arg-write path). This is the least
invasive option and directly enables label-driven containers. (Rejected: a full
slots/named-children API — heavier; revisit only if multi-slot containers land.)

**Steps**
1. Core: in `entry-processing.js`, add `args` to the returned `ChildBlockResult`
   (+ the `ChildBlockResult` typedef). Confirm no consumer mutates `child.args`.
2. Core blocks `tab` + `tabs` in `app/blocks/builtin/`:
   - `tab` — `container: true`, `args: { label: richInline }`, renders its
     children as the panel body.
   - `tabs` — `container: true`; reads `child.args.label` for the strip; tracks
     `activeIndex`; live renders the strip + the active tab's panel. Reads
     `debugHooks.isEditPresentation` → when set, render ALL panels stacked
     (same pattern as `carousel`/`accordion`), so no chrome nav-exemption is
     needed (tab switching isn't required while every panel is visible).
3. Register in `builtin/index.js`; SCSS `_tabs.scss` (+ `_index.scss`); i18n
   `blocks.builtin.tabs.*` / `tab.*`.

**Files:** `lib/blocks/-internals/entry-processing.js`; `blocks/builtin/tabs.gjs`,
`tab.gjs`, `index.js`; `stylesheets/common/blocks/_tabs.scss` + `_index.scss`;
`config/locales/client.en.yml`.

**Verify:** unit — `ChildBlockResult` now carries `args` (extend an
entry-processing/block-outlet test). Integration — a `tabs` of two `tab`s
renders a 2-button strip from labels + the active panel live; with
`EDIT_PRESENTATION` set, both panels render. Regression: `block-outlet` 91 stays
green.

---

## P2 — Harden the shipped data/route blocks with integration tests — ✅ SHIPPED

**Status:** Done & green. Added live-data render coverage:
- `tests/integration/components/block-featured-data-test.gjs` — `featured-tags`
  / `featured-users` driven through the real store + pretender (resolved + empty
  branches).
- `tests/acceptance/block-tag-banner-test.gjs` — `tag-banner` route-gating
  (renders on `/tag/:slug/:id`, absent off-route).

**Bugs the tests surfaced + fixed (all on the production render path that the
mocked-store unit tests missed):**
1. `tag-banner` displayed the numeric `tag_id` → now `tag_slug` (the tag name).
2. `featured-users` had a self-closing `<DUserLink />` (empty link) → now passes
   the username as content.
3. `fetch-tags`/`fetch-users` did `Array.from(resultSet)` (tripped the
   `proxied-array` deprecation) → now read `result.content ?? result`.
4. `ignoreUnsent: false` was dead on these fetchers (neither `store.findAll` nor
   `RestAdapter.find`/`findAll` forwarded ajax opts). Fixed generically:
   `store.findAll` now threads `opts`, and `RestAdapter.find`/`findAll` forward
   `{ ignoreUnsent: opts?.ignoreUnsent }` to `ajax` (mirroring `topic-list.js`).
   Backward-compatible — undefined opts keep ajax's default. Now matches the
   `fetch-topic-list` reject-on-unsent contract.

**Files:** the two new test files; `blocks/builtin/tag-banner.gjs`,
`featured-users.gjs`; `lib/blocks/-internals/fetch-tags.js`, `fetch-users.js`;
`services/store.js`, `adapters/rest.js`.

**Follow-up (not done):** no direct test asserts rejection on an UNSENT request
(`readyState === 0` is impractical to simulate via pretender); the plumbing
mirrors the trusted `topic-list.js` path. A focused adapter unit test (mock
`ajax`, assert `find`/`findAll` forward `ignoreUnsent`) could lock it in.

---

## P3 — Phase 7 editor scale polish

Split into two parts (the multi-select piece reworks the single-selection model
that 44 sites read, so it got its own scoped item).

### P3a — outline compaction + bulk duplicate ×N — ✅ SHIPPED

**Status:** Done & green.
1. **Outline child-count compaction** (`lib/walk-layout.js` + `outline-panel.gjs`):
   rows carry `childCount`; a container with **more than 6** children defaults
   collapsed (default-aware `#collapseOverrides` trackedMap — the user's toggle
   wins), and a collapsed container shows a `× N` badge.
2. **Bulk duplicate ×N** (`services/wireframe.js` + `block-toolbar.gjs`):
   `duplicateBlock(blockKey, count = 1)` batches `count` clones into one undo
   step; the toolbar's Duplicate button is a `DComboButton` (×1 button + a
   `DDropdownMenu` of ×2/×3/×5/×10 + custom-count row). Styled compact to match
   the flat toolbar; dropdown addressed via `.wireframe-duplicate-count-content`.

**Tests:** `service:wireframe` (duplicate count = one undo + clamp),
`outline-panel-test.gjs`, `block-toolbar-duplicate-test.gjs`.

### P3b — multi-select + bulk delete — ✅ SHIPPED

**Status:** Done & green. Outline-driven multi-selection, canvas reflects it:
- `services/wireframe.js`: `selectedKeys` trackedSet (primary stays
  `selectedBlockKey`); set-aware `isBlockSelected` (free canvas highlight);
  `selectBlock(data, { preserveMultiSelection })`; `toggleBlockSelection` /
  `setSelectionRange` / `hasMultiSelection`; `removeBlocks(keys)` deletes the set
  in one undo (skips outlet roots, parent+child safe) via an extracted
  `#removeEntryFromLayout`.
- `outline-panel.gjs`: cmd/ctrl-click toggles, shift-click range, plain resets.
- `inspector-panel.gjs`: bulk-action panel ("N blocks selected" + Delete) when
  >1 selected; per-block form at exactly one.
- `editor-shortcuts.js`: Delete removes the whole selection when >1.

**Tests:** `service:wireframe` (+5), `outline-panel-test.gjs` (+3 gestures),
`inspector-multi-select-test.gjs`.

**Out of scope (later):** bulk duplicate/move of a selection; canvas-built
multi-select (cmd-click on the page); marquee drag-select.

---

## P4 — Carousel slide-manager, paged-in-place editing, accordion exclusivity

**Why:** rounds out the collapsing-family authoring UX beyond the shipped
EDIT_PRESENTATION expand-all.

**Steps**
1. **Inspector slide-manager** (`components/editor/inspector-carousel-slides.gjs`,
   carousel-only): a DnD list of slides (thumbnail + label) reusing the outline's
   dnd primitives (`dDragAndDropSource`/`Target`) + `moveBlock`/`insertBlock`/
   `removeBlock`. Clicking a row selects/pages to that slide.
2. **Paged-in-place editing** (optional): let the carousel page in the editor
   (instead of, or alongside, expand-all). Requires a chrome nav-exemption —
   mark prev/next/dots with a data-attr that `block-chrome.gjs onClick` lets
   through, so paging works while the block stays selectable.
3. **Accordion exclusivity:** one-open-at-a-time via `<details name="…">`. Needs
   a shared group name on each item — supply it from the `accordion` parent via
   `childArgs` (a `group` namespace) or derive from the parent key. Depends on
   the same parent→child plumbing as P1; do after P1.
4. **Tabs "add tab" strip affordance** (editor-only, `tabs`): an editor-chrome
   "+" at the end of the tab strip (rendered only under `EDIT_PRESENTATION`)
   that appends a child to the `tabs` container and selects it — the lightweight
   cousin of the carousel slide-manager above. Today a tab is added via the
   generic container flow (drag-in / duplicate), which isn't discoverable for a
   tabbed UI. Keep it as editor chrome (data-attr + portal), not live render.

**Files:** `blocks/builtin/carousel.gjs`, `accordion.gjs`/`accordion-item.gjs`;
`components/editor/inspector-carousel-slides.gjs`, `block-chrome.gjs`.

**Verify:** slide-manager add/remove/reorder routes through `moveBlock` (unit);
accordion exclusive mode opens one at a time (integration); paging works in the
editor (system).

---

## P5 — Table cell-placement editor UI (the grid overlay over a table)

**Why:** the `table` block ships usable via auto-fill, but lacks the cell-precise
placement / span-resize overlay the `layout` grid has.

**The blocker (verified):** the grid overlay is hard-coupled to the `layout`
CSS-grid DOM — `grid-overlay.gjs` queries `.d-block-layout` (`GRID_LAYOUT_SELECTOR`,
~:584) and reads `getComputedStyle().gridTemplateColumns` (~:469) to position
cells. A semantic `<table>` has neither.

**Design decision — make the overlay geometry-based.** Position cells by
measuring the rendered cell elements' rects (works for `<td>` and CSS-grid cells
alike) instead of parsing `gridTemplateColumns`, and select the grid container
by a generic data attribute (e.g. `[data-grid-editable]`) rather than
`.d-block-layout`. Then re-apply the `gridEditable` ungating reverted in task #9
(`wireframe.js isGridContainer`, `block-chrome.gjs isGridLayout`). This benefits
any future grid-editable container, not just the table. (Alternative, faster but
hackier: a table-specific overlay, or an edit-mode CSS-grid mirror render.)

**Steps**
1. Refactor `grid-overlay.gjs` cell positioning to be rect/geometry-based;
   replace the `.d-block-layout`-specific selector + `gridTemplateColumns` read.
2. Re-apply the `gridEditable` generalization (the two getters reverted in #9).
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

1. **P1** child-args capability + `tabs` (unblocks the last primitive; cheap, reused by P4).
2. **P2** integration/acceptance tests for the shipped data/route blocks (cheap hardening).
3. **P3** editor scale polish.
4. **P4** carousel slide-manager + accordion exclusivity (builds on P1).
5. **P5** table cell-placement overlay (highest risk — geometry-based overlay refactor + visual verification; keep the grid chokepoint tests green).
6. **P6** `recent-posts` (gated on a backend endpoint decision).
