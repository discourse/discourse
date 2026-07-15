# RFC + Plan: Replacing select-kit with a ui-kit select family

## Context

`select-kit` is Discourse's dropdown/select library (~90 files under
`frontend/discourse/select-kit/`), used in ~282 consumer files across core `app/`,
`admin/`, and bundled plugins. It is showing its age: a 1,339-line classic-Ember
god base (`select-kit/components/select-kit.js`), deep inheritance chains, a
hand-rolled `@floating-ui` positioning stack that predates and bypasses FloatKit,
triplicated keyboard handling, and a partial/incorrect ARIA pattern
(`role="menu"` + `menuitemradio`) that has caused **repeated, documented
accessibility failures for screen-reader users over the years** (dev topics
#25410, #28314 Blizzard audit, #46013 NVDA/JAWS — 88 posts). Its author (Joffrey)
has repeatedly said we should stop investing in it and replace it
(dev #185600, #160892).

A replacement has already begun organically but unevenly on `main`: `DSelect`
(native `<select>`), `DMultiSelect` (async multi, but with an HTML-validity bug
and hand-rolled keyboard/debounce), and `DIconGridPicker` (grid single-select on
`DMenu` + `DAsyncContent`). There is no unified abstraction — three one-offs, each
re-solving trigger/filter/selection/keyboard.

This plan defines the target architecture, the extension API, the migration
strategy, an uncompromising accessibility contract, and a concrete first build
(Phase 0). It is written to double as an RFC for alignment with Joffrey/Martin
before the large migration.

## Goal

A single, modern, **accessible-by-construction** and **async-first** ui-kit select
family that replaces select-kit: excellent keyboard + screen-reader support, and
first-class async (loading / empty / error status, debounce, request cancellation,
out-of-order safety, and preselected-value resolution) as a **core capability rather
than a per-picker bolt-on** — the opposite of select-kit, whose base is a synchronous
`content` array with async layered on by overriding `search()`. Built only on
sanctioned foundations (FloatKit, `DAsyncContent`, `dRovingFocus`), extended via
the standard transformer API, with a migration path that keeps every existing
third-party contract working — select-kit stays (deprecated) for out-of-repo
consumers, while core and bundled plugins migrate off it and are banned from using it.

## API refinement — gap analysis & decisions (2026-07-07, post-Phase-0 review)

After Phase 0 shipped (draft PR #41534) we audited the proposed API against (a)
select-kit's full customization surface, (b) the RFC feedback on dev #187302, and (c)
two modern references — shadcn/Base-UI Combobox and React-Aria ComboBox. This section
records the gaps and the decisions; it refines the component API for Phase 1 and
**supersedes the "Interaction modes" section and the mobile "Open decision" below**
where they conflict.

**Already at modern baseline:** controlled `@value`, async-first with `AbortSignal`,
create-on-the-fly (`@allowCreate`/`@createItem`), disabled options (`item.disabled`),
action rows (`item.onSelect`), selected-value resolution, WAI-ARIA combobox/listbox,
optional `:item`/`:selection` slots (the render-prop equivalent), with a
`@labelField` fallback when either is omitted.

### Decision 1 — Typeahead is the default trigger (button becomes a variant)

chapoi (UX) asked for a true typeahead where the control itself is the search input
(as mini-tag-chooser already does); it is the default in React-Aria and shadcn; and it
**is our own accessibility thesis** — the fix for select-kit's #1 failure ("typing
into a button") is a real `role="combobox"` input, so the editable input should be
present by default, not only after opening. Three variants via `@variant` (default
`typeahead`):

- **`typeahead`** (default, searchable): the trigger IS a `role="combobox"` input.
  With the default field presentation, it shows the resolved selected label, selects
  that label on focus, and replaces it with the query on the first edit. A custom rich
  `:selection` renders beside the input instead and is hidden while editing. Selecting
  fills the presentation and closes. Selection stays controlled via
  `@value`/`@onChange`; the typed query is engine-internal `filter` state — so we need
  not expose `@query` in v1.
- **`button`** (variant, searchable): the current button trigger + in-panel
  `DFilterInput`. For rich value display the input can't render — a category badge
  (with color), a user avatar, a menu-style value picker; `:selection` renders it.
- **`static`** (variant): short lists, no search; the listbox takes focus (roving
  `focus` mode). The native-`<select>` replacement.

**`@variant` is the single canonical control** (review finding). `@searchable` can't
distinguish `typeahead` from `button` (both are searchable), so it's the wrong axis.
It is **brand new in Phase 0 and unreleased** — no external consumers, only our own
tests and (soon) presets — so there's nothing to deprecate: **replace `@searchable`
outright with `@variant`** and update the Phase-0 component + tests
(`@searchable={{false}}` → `@variant="static"`). Presets pick per use case
(user/tag/topic → typeahead; category-with-badge, notification-level → button).

**Per-breakpoint (verified against FloatKit):** desktop typeahead keeps focus in the
trigger input with `@trapTab={{false}}` + `dRovingFocus active` mode pointing
`controllerElement` at that input. **Open behavior defaults to React-Aria's
`menuTrigger:"input"`** — open on typing / click / ArrowDown, **not** on bare focus,
so tabbing through a form doesn't pop every select open (wired manually via
`componentArgs.show`, since FloatKit has no built-in "input" trigger; an `@openOn`
knob can offer `focus`/`manual`). On **mobile**, an
external input cannot hold focus behind FloatKit's `aria-modal` `DModal`, so typeahead
opens `DMenu`'s modal with the input **inside** it (real focus there) — which is also
the mobile a11y fallback (Decision 3) and the better small-screen UX. Use `DMenu` for
all variants: it accepts the typeahead's non-button trigger component, yields the
expanded state needed by the input's ARIA wiring, matches the trigger width, and owns
the mobile modal. The typeahead input intercepts Tab so `DMenu` does not forward focus
into the portaled content.

**Multi × typeahead — the shadcn Base-UI `multiple` pattern (user-endorsed).**
(https://ui.shadcn.com/docs/components/base/combobox#multiple; select-kit's
`useHeaderFilter` / `multi-select-header.gjs:70-98` is the migration parity target.)
The multi trigger is a `ComboboxChips`-style box: selected items render as chips
**inline with** a flexible `role="combobox"` input (input after the chips, growing to
fill and wrap), the input — not the Phase-0 separate expand button — as the focus
target. Behavior:
- Selecting **adds a chip and keeps the popover open**; the chosen item **stays in the
  list with a selected indicator** (checkmark / `aria-selected="true"`) and toggles on
  re-click. This **supersedes Phase-0 multi behavior** — the engine currently *removes*
  selected items from the list in `buildItems` (and a Phase-0 test asserts "the picked
  item leaves the list"); change multi `buildItems` to keep + mark selected and update
  that test + add a checkmark to `SelectItem`.
- **Backspace on the empty input removes the last chip**; `@clearable` is the clear-all
  (distinct from per-chip removes).
- Placeholder ("Add …") in the inline input, suppressed once chips are present.
- `@value` is the id array; `aria-activedescendant` on the inline input (active mode).
- Mobile: chips + input move into the modal surface (Decision 1's mobile arm).

Multi's **default variant is also `typeahead`** (consistent with single); `button`
stays available for rich-display multi. `resolveSelection` already returns an array for
multi, so the data layer is ready — the Phase-1 work is the chips+inline-input trigger,
focus/keyboard, and the keep-selected `buildItems` change.

**Typeahead build requirements (review findings — bigger than "invert the trigger").**
The pivot relocates focus and the input into the trigger, which breaks three things the
Phase-0 panel structure got for free:
- **Skeleton can't live in an `<input>`.** The "content-only trigger skeleton" is
  button-variant-only. Typeahead needs the resolving skeleton rendered *outside* the
  input (overlay/adjacent), and a display getter that returns the placeholder (never a
  skeleton, never a raw id) while `resolveSelection` is pending.
- **Display-value vs edit-value split.** `DFilterInput` binds one value; typeahead
  needs the input to show the resolved label unfocused and the query focused. Add a
  focus-aware `@displayValue` (or a purpose-built input), and **reset the filter to ""
  on blur/close** so the revert is a cached/sync resolve, not a re-fetch flash.
- **Escape + click wiring is explicit, not inherited.** FloatKit's close-on-escape
  handler lives on the *portaled body*; with focus kept on the host input, Escape never
  reaches it — route Escape/close through `engine.requestClose()` on the input path.
  Register with **empty `triggers`/`untriggers`** and drive open/close from input
  events (type / ArrowDown / click-to-open; Escape / select / blur to close), or a
  click on the open input will untrigger and close it.
- **Two DOM topologies.** Desktop = input-as-trigger; mobile = collapsed trigger +
  input inside the modal. The single `filterInput`/`controllerElement`/`getElement`
  wiring must branch per arm.
- **Bridge anchor stays host-DOM.** `legacy.getElement` must resolve to a node inside
  `#reply-control` on *both* arms — do **not** point it at the modal input on mobile
  (it's portaled out, so AI content callbacks' `.closest("#reply-control")` returns
  null). The positioning trigger and the legacy anchor may be two distinct nodes.
- Consider `aria-owns` on the input → portaled listbox for SR relationship (matrix).

### Decision 1b — Trigger & list rendering states (typeahead × single/multi × async)

The hardest part of the design: how the shared primitives (`:selection`, `:item`,
`DSkeleton`, `DAsyncContent`'s loading/empty/error) compose in a typeahead where the
trigger is an `<input>`. Planned exhaustively.

**Foundational architecture — separate default and rich-presentation paths.** An
`<input>`'s value is a plain string, so the default single-select path can use it for
both a resolved `@labelField` display value and the active query, with explicit editing
state separating the two. Skeletons, chips, and rich `:selection` markup cannot render
inside an input, so those stay in the **composite box** as siblings, laid out
inline-start → inline-end:

`[leading @icon] · [selection presentation] · [query <input role=combobox>] · [clear] · [caret]`

For a block-free single select, the input displays the synchronously available resolved
label until editing begins; while editing it displays `engine.filter`, which resets to
`""` on close/select so the cached label returns. If resolution finishes while the
input is focused, the reactive cache updates the same mounted input and selects the new
label. When `:selection` is supplied, that rich presentation is a sibling and the input
carries only the query. Multi selection chips and resolving skeletons are also siblings.

**Two independent async surfaces, both on the improved `DAsyncContent`:**
- **Selection surface** (trigger): `resolveSelection(@value)` → bound id(s) → display.
- **List surface** (panel): `loadItems(query)` → options.
They never block each other: the list can be loading while the selection resolves, and
vice-versa.

**Selection surface (trigger) — state × arity:**

| `@value` state | single renders | multi renders |
|---|---|---|
| none | input placeholder | input placeholder ("Add …") |
| resolving (pending) | text/rich skeleton sibling; **hidden while the user is actively typing** (shown again on blur) | **cached chips render immediately; uncached ids resolve in ONE batch** (`@resolveValues`), skeleton chips until it returns |
| resolved | input value from `@labelField`, or custom `:selection` content (sibling) | label-field or custom `:selection` chip per id (removable) |
| unresolvable (404 / restricted / omitted) | a **fallback presentation** (see below) — never hidden, never blank | a **fallback chip** per unresolved id (see below) — never dropped |

**List surface (panel) — independent:**

| state | renders |
|---|---|
| initial load | `:loadingItem` compound skeleton rows × `@skeletonCount` (mirrors `:item`) |
| re-filter (query changed, had results) | keep prior rows (`@retainWhileReloading`) + `aria-busy`; no blank flash |
| load-more (pagination) | existing rows + an end-of-list load-more skeleton |
| content | `:item` rows; **multi marks selected rows with a checkmark and keeps them** |
| empty | `:empty` block / no-results `role=status` (polite announce) |
| error | `:error` + retry |

**Skeleton taxonomy — three distinct shapes (all `DSkeleton`, reduced-motion-aware):**
1. **List-row skeleton** — `:loadingItem` (compound: avatar + text for user/topic rows),
   repeated `@skeletonCount`; default a single text bar.
2. **Chip skeleton** (multi trigger) — a chip-shaped pill (avatar + short text for user),
   one per unresolved id; overridable via `:selectionLoading`.
3. **Single-trigger skeleton** — a text-width (or rich) skeleton for the one resolving
   value; overridable via `:selectionLoading`.

**Focus / query lifecycle (typeahead):**
- Unfocused with a selection → the input shows the label-field fallback, or a custom
  selection presentation is shown with an empty input.
- Open (per `@openOn`: type / ArrowDown / click, not bare focus) → list loads (`query=""`
  → initial results).
- Typing → the first edit switches the input from its fallback label to the query;
  **single hides any custom selection presentation** (query owns the box);
  **multi keeps chips**, input flows after them. Clearing the query does not leave edit
  mode; close/select restores the selection presentation.
- Select — single → commit `@value`, close, reset query; the picked item was cached on
  select, so the new label resolves **synchronously** (no skeleton flash).
- Select — multi → append id, **popover stays open**, new chip appears (cached → sync),
  reset query to `""`, focus stays in the input.
- Blur / Escape without selecting → reset query to `""`; selection presentation returns
  (cached → sync, no re-fetch flash); close.

**Edge cases (explicitly handled):**
- *Resolving while typing*: no conflict — the input is the query (editable); the
  single skeleton is hidden behind the query and reappears resolved on blur; multi
  skeleton-chips resolve inline as the user keeps typing.
- *Picked-from-list items never skeleton* — `select()` caches the full item.
- *Partial multi* (`@value=[1,2,3]`, 1–2 cached, 3 uncached): chips 1–2 render
  immediately from cache; the uncached id is resolved in the **single batch request**
  and shows a skeleton chip until it returns (one request, not per-chip — see below).
- *Long single label* → ellipsis; *many chips* → wrap, box grows.
- *Clear-all mid-resolve* → clears `@value`, the resolve no-ops.
- *List loading with focus retained* → `aria-busy` listbox, input keeps focus +
  `aria-activedescendant`.
- *IME / composition input* (CJK, dead keys): do **not** fire the filter mid-composition
  — gate query updates on `compositionstart`/`compositionend` so a half-composed string
  doesn't search or open. (`DFilterInput` does not handle this today — a real gap.)
- *Mobile placement split*: on mobile the **closed trigger** (host DOM) shows the
  selection presentation (single label / multi chips) so the user sees the value without
  opening; tapping opens the modal that holds the **query input + list**. So on mobile
  the selection presentation and the query input live in different nodes (the two-DOM
  topology), unlike the single desktop box.
- *Create row × multi* → selecting the synthetic create row appends a chip like any
  pick; *toggling an already-selected row* removes it (checkmark model).
- *Chip add/remove + result count* announced politely via the `a11y` service.

**Selection resolution — batch, fallbacks, and model normalization (design directives):**

*Batch, never fan-out.* Resolving a multi selection uses a **single batch request** —
`@resolveValues(ids, { signal })` returns items for the uncached ids in one call (single
uses `@resolveValue(id, { signal })`). We **require** a batch-capable endpoint rather
than resolving per-chip: N chips must never mean N requests (server flood). Cached ids
(picked from the list, or seeded via `@selected`/`@selectedItems`) never hit the
network; only the uncached remainder is batched. This supersedes the earlier "per-chip
`DAsyncContent`" idea — multi `resolveSelection` stays a single `DAsyncContent` over the
whole value driven by `@resolveValues` (drop the `Promise.all` at `select-engine.js:292-295`).

*Fallback for every id — never hide a held value.* A bound id may fail to resolve: a
404, a restricted topic/category the user can't see (single), or an id the batch
response omits (multi). We must **never** drop the chip or blank the single trigger, or
`@value` silently disagrees with what's shown. So resolution **always maps each id to
either a resolved item or a synthetic fallback** `{ [valueField]: id, __unresolved: true }`
— the engine catches resolve errors and fills omissions rather than rejecting, so the
trigger's `DAsyncContent` never enters error/flash mode (a review finding: the trigger
resolve has no `:error` block, so a rejection would render a `role=alert` flash *inside*
the trigger). The fallback renders a default "unavailable" presentation (a translatable
label / the id shown minimally / a muted style) and stays **removable/clearable**; a
`:unresolved` block (defaulting to `:selection`, which can branch on `item.__unresolved`)
lets a preset customize it (e.g. "Restricted topic"). This makes the topic-picker's
restricted-404 case first-class.

*Model normalization (no `id` assumption).* Not every model has an `id`, yet the listbox
keys `{{#each … key="id"}}` (`d-select.gjs:327`) and chips key on identity — both break
for `@valueField="username"`, primitive-value lists, and synthetic rows (create /
special / unresolved) that carry no natural id. So the engine **normalizes** every
rendered and selected entry into an internal descriptor `{ key, value, item, flags }`:
`key` = the `@valueField` value (or a synthesized unique key for synthetic rows),
`value` = the id, `item` = the **raw model** yielded untouched to `:item`/`:selection`,
`flags` = `{ selected, disabled, group, __create, __unresolved }`. The template keys on
`key` (always present; never collides across paginated pages or on id-less rows), and
consumers still render their own fields from the raw `item`. `@valueField`/`@labelField`
become the single source of truth for identity and label; `key="id"` is removed.
Normalization is the **final step before render** — the `select-content` transformer,
the `modifySelectKit` bridge, and `item.onSelect` all still operate on **raw items**;
only the rendered/selected descriptors wrap them, so the extension pipeline is unchanged.

**Additional review findings folded:**
- *`reload()` must show loading despite `@retainWhileReloading`* — the AI spinner→results
  flow (nonce bump, `select-engine.js:386-389`) is the headline case; retain currently
  suppresses the spinner (`d-async-content.gjs:72-73`). A forced reload must show a
  visible busy state (bypass retain, or overlay a spinner on the retained rows).
- *Re-filter from an empty result* shows a busy indicator, not a frozen "No results".
- *Retained list needs `aria-busy` + a stable listbox id/role* — the loading `<ul>`
  (`d-select.gjs:296-304`) must carry the same `id` + `role="listbox"` so the combobox's
  `aria-controls`/`aria-activedescendant` never dangle during the initial load;
  `DAsyncContent` needs a reloading flag to drive `aria-busy` on retained content.
- *Chip removal keeps the popover open and moves focus to the input* — removing the
  focused chip `<button>` must not blur-close the menu (`d-select.gjs:170-174`).
- *Dedup multi `@value` on read* — a controlled parent may pass duplicate ids; the value
  getter de-duplicates so chips don't collide on `key`.
- *Auto-highlight / active-descendant run against the CURRENT rows* — while stale rows
  are retained, don't reset the highlight until the new rows land; on replacement, reset
  and scroll the active option into view.
- *Immutable `@value` contract* — in-place array mutation is unsupported (it would update
  list checkmarks but not the trigger chips); `@onChange` must be applied as a new value.
- *Eager resolution is by design* — the single/multi trigger resolves on mount so the
  saved label shows before first open (the fetch-to-display point); mitigate page-wide
  fan-out via the cache + the `@selected`/`@selectedItems` escape hatch, not lazy resolve.
- *Dev-warning* when `@value` is set on a server source with neither `@selected` nor
  `@resolveValue`/`@resolveValues` (no way to get a label → silent empty trigger).
- *Panel repositions* as the multi trigger grows/wraps (`@matchTriggerWidth` + autoUpdate).

**Engine/component changes (Phase 1):** batch `@resolveValues` (one request, no
per-chip); resolution never returns `undefined` (synthetic `__unresolved` fallback item
on error/omission); an item **normalization layer** (`{ key, value, item, flags }`
descriptor, replacing `key="id"`); keep-selected-with-checkmark `buildItems` for multi;
query reset on blur/close/select; multi `@value` dedup; a `reload()`-shows-busy path; a
`DAsyncContent` reloading flag for `aria-busy`; and the `:selectionLoading` / `:unresolved`
blocks.

### Decision 2 — Group/section-aware item model designed in now

select-kit supports hierarchy (category subcategories) and both references treat
sections as a core collection concept. Retrofitting grouping into `buildItems` +
`dRovingFocus` + ARIA later is painful, so we design the model now (build the UI when
the category family needs it, Phase 4):

- Options may declare a group (an item `group` key, or a `@groupBy` field/fn); the
  listbox renders `role="group"` sections with a header.
- The engine + transformers keep operating on a **flat** item array — grouping is a
  presentation view over it — so `select-content` and the bridge are unaffected.
- `dRovingFocus` needs no change: `itemSelector="[role=option]"` already skips
  non-option header rows, so keyboard nav stays correct.

**Groups × pagination (boundary).** Because grouping is a pure client-side view over
the accumulated flat list, it composes with complete/client lists but collides with
infinite/linear server pagination: an appended page's items can slot into *earlier*
group sections (above the load-more sentinel), reflowing content above the viewport.
So v1 does **not** combine grouping with paged loading in one picker — in practice they
serve different pickers (grouped = category hierarchy / complete sectioned lists;
paged = flat ranked user/tag search). A future grouped-and-paged picker would need the
server to return complete groups (or top-N per group) per page — a 2D-pagination
extension out of v1 scope. Keyboard/roving is unaffected (headers and the load-more
sentinel are non-option rows, skipped).

### Decision 3 — Mobile: don't block on d-sheets

Mobile screen readers ignore `aria-activedescendant`, so searchable comboboxes need a
real-focus fallback in `DModal` (input inside the surface, per Decision 1's mobile
arm). Ship that now and adopt the in-flight **d-sheets** framework when it lands rather
than blocking on it (coordinate with jaffeux/renato). Tracked as an open question with
an on-device SR check; simple/static mobile already uses real focus.

### Decision 4 — RTL & i18n (cross-cutting)

Yes, RTL is first-class (Discourse ships RTL locales; select-kit hand-rolled
direction-aware placement — we improve on that):

- **CSS logical properties only** — no physical `left`/`right`. The Phase-0
  `d-combobox.scss` already complies (`margin-inline-start`, symmetric padding); the
  caret, clear button, leading icon, and chips must position via inline-start/end so
  they mirror.
- **Positioning is RTL-aware for free** — FloatKit's floating-ui `-start`/`-end`
  placements resolve against reading direction, so the default `bottom-start` mirrors
  correctly without the manual direction computation select-kit needed.
- **Input text direction** follows the document/locale; no forced `text-align`.
- Both reference libraries (Base-UI, React-Aria) treat RTL as standard; we match.
- Added to the verification matrix (RTL locale × both themes) below.

### Decision 5 — Large-list performance: bounded windowing, not virtualization

A synchronous source can hand us thousands of items; rendering them all on open hangs
the tab (we've hit this pain before). Pagination fixes server sources but not a known-
complete 5k **client** list — so this must be designed in from the start. Approaches:

| Approach | How | Pros | Cons |
|---|---|---|---|
| **A. True DOM virtualization** | render only the visible window over the full array, recycle on scroll | scroll the whole list continuously; constant DOM at any N | **net-new in core** (no primitive; post-stream *cloaking* isn't reusable and keeps all rows in the DOM anyway); **breaks our a11y/keyboard layer** — `dRovingFocus` + both existing pickers enumerate options from the DOM (`querySelectorAll`/`offsetTop`/index) and assume all are present; needs net-new `aria-setsize`/`aria-posinset` + windowing-aware keyboard + render-then-focus for off-screen active rows + row-height measurement. Fights the headline "accessible by construction". |
| **B. Bounded windowing + reveal** (recommended) | render a capped window (internal chunk; server page size auto-detected); reveal more via the SAME `DLoadMore` sentinel up to a hard `MAX_RENDERED` cap, then "filter to narrow" — server fetches the next page, a sync source slices the next chunk (no network); filtering re-slices | reuses `DLoadMore` + `d-observe-intersection`; **bounded DOM**; `dRovingFocus`/keyboard/ARIA work **unchanged** (every option is a real node); matches select-kit's idiomatic "server `limit` + filter-for-more"; trivial perf (slice + ~100 rows); unifies sync + async | can't scroll all 5k continuously — must reveal-more or (the intended path) filter |
| **C. Hybrid** | ship B now; keep A behind the same seam for a future browse-all need | safe one-way door | — |

**Recommendation: B, framed as C.** Bounded windowing is the shipped model; the seam
(and `aria-setsize`/`aria-posinset` from day one) leaves virtualization a future
drop-in if a genuine browse-the-whole-list case ever appears. Reasons: (1) **preserves
accessibility-by-construction** — every rendered option is a real DOM node, no new
keyboard/focus machinery; virtualization would reintroduce exactly the hand-rolled
focus/ARIA complexity this project exists to eliminate; (2) **reuses proven infra**
(`DLoadMore`) + select-kit's idiomatic capping, vs net-new virtualization (post-stream
cloaking is not reusable); (3) the **5k-node hang is eliminated at the source** (never
rendered); (4) the intended interaction for a huge list is **filter, not scroll**, so B
makes the happy path fast and honest; (5) **unifies sync and async** — one windowing
model, sync slices locally, server pages, both via the same sentinel + "N of M" hint.

**Design:**
- **No public `@pageSize`.** The render chunk is internal: a **client** source uses a
  sensible internal default (~50–100); a **server** source **auto-detects** its page
  size from the first response's length — the backend owns its paging default, so we
  don't dictate or second-guess it.
- **Hard `MAX_RENDERED` upper bound** (a fixed constant, a few hundred rows) on the
  total items ever rendered/loaded — the guard against the degenerate case while there
  is no true virtualization. It caps **both** sources regardless of how many times the
  user reveals more.
- Reveal = a `DLoadMore` sentinel inside the listbox scroll container (`@root` = the
  listbox). On reveal: **sync** → widen the slice (no network); **server** → fetch +
  append the next page — **up to `MAX_RENDERED`**. ArrowDown at the last rendered row
  reveals the next chunk, then moves into it.
- **At `MAX_RENDERED` with more still available → stop loading and show a "keep typing
  to narrow the list" message** (the `filter-for-more` affordance); never keep loading
  into the degenerate case. Filtering shrinks the set back under the cap.
- `aria-setsize` = the true total when known (client: full filtered count; server:
  total if the response provides it), `aria-posinset` per option — so SR users know the
  list extends beyond the rendered window / the cap.
- The engine windows the **final** (filtered → transformed → normalized) descriptor
  list; a query change or `reload` resets the window to the first chunk.
- **Groups × windowing**: *client* windowing (slicing a known-complete list) composes
  with `@groupBy` — the full order is known, headers stay stable. This refines Decision 2:
  only *server infinite pagination* + groups is out of scope (reflow); client windowing +
  groups is fine.

### Decision 6 — Author the family in TypeScript (PR #41478)

Since [#41478](https://github.com/discourse/discourse/pull/41478) core can author
`.ts`/`.gts` with full TypeScript (reference migration: `app/ui-kit/d-button.gts`;
docs: `docs/developer-guides/docs/03-code-internals/26-types.md`; tsconfig not yet
strict). This was floated on the RFC (David) and we adopt it — the select family is a
clean greenfield to pilot proper TS, and types make the "coherent API" *enforceable*
rather than documented.

**Execution prerequisite — rebase first.** The worktree is ~23+ commits behind
`origin/main` and predates #41478, so its build cannot compile `.ts`/`.gts`. First
execution step on approval: **rebase `select-kit-rework` onto latest `origin/main`**
(resolve any conflicts in the touched shared files), then convert. Re-aim draft PR
#41534 to ship TS.

**Convert to TS.** The net-new select-family files — `select-engine.js → .ts`,
`d-select.gjs → .gts`, `-internals/select-item.gjs → .gts`,
`-internals/modify-select-kit-bridge.js → .ts`, and the new engine/bridge/component
tests → `.ts`/`.gts` — **plus the three foundational primitives this family owns or
co-lands** (user-approved):
- `d-async-content.gjs → .gts` — a widely-consumed shared primitive, so the conversion
  must **preserve its public signature** (`.gjs`/`.gts` consumers import it
  transparently); type its args + block params (`asyncData`, `context`, and the
  `:loading`/`:content`/`:empty`/`:error` yields).
- `modifiers/d-roving-focus.js → .ts` and `d-skeleton.gjs → .gts` — the two ported
  primitives; converting means the **editor branch adopts these TS versions** when it
  reconciles (drops its copies) — coordinate that hand-off.

**Stays JS:** only `d-icon-grid-picker/content.gjs` — a pre-existing component we merely
touched for a11y (0g); it isn't central to the select family and carries a larger,
unrelated surface, so converting it is out of scope for this PR.

**Typed surfaces (the design win):** `SelectEngineOptions`; the raw-item generic + the
normalized descriptor `{ key, value, item, flags }`; the `@value` type (scalar for
single, array for multi); the `@variant` union (`"typeahead" | "button" | "static"`);
`@resolveValue`/`@resolveValues`, `@load`, `@filterBy` signatures;
`onChange(nextValue, item | items)`; the transformer/bridge context types; the
`DSelect` Glint `Signature` (`Args` / `Blocks` / `Element`); and typed `Signature`s for
the converted primitives — `DAsyncContent` (generic over the resolved value),
`DSkeleton`, and the `dRovingFocus` modifier.

*Strictness scope:* **write strict-grade TS regardless** — the loose global config is
not a license for sloppiness. Author *as if* `strict` were on: no `any` (implicit or as
an escape hatch), proper `null`/`undefined` handling, real generics over the item/value
types, precise `Signature`s, and no `@ts-ignore`/`@ts-nocheck` crutches; the new files
should type-check clean even under strict. The only thing we must **not** do is edit the
shared `tsconfig-base.json` to flip the repo-wide flags in *this* PR — that's a
separate, repo-wide initiative #41478 flagged for later and would ripple into unrelated
files. (Optionally, a `strict`-scoped tsconfig covering `app/ui-kit/select/**` could
*enforce* the bar locally without touching the global config — nice-to-have, not
required.)

### Reference-library reconciliation (React-Aria + Base-UI props → our proposal)

Every React-Aria ComboBox and Base-UI Combobox prop was mapped against our surface.
The bulk map directly (selection, disabled options, sections, clear, async +
cancellation, placeholder, custom filter fn, auto-highlight, chips/multi, labels via
`...attributes`, custom-value). The genuine deltas and their disposition:

| Reference prop | Our proposal | Disposition |
|---|---|---|
| RA `inputValue`/`onInputChange` (controlled query) | internal `filter` state | **Deferred v1** — expose `@query`/`@onFilter` only if a picker needs external query control (async-first pickers rarely do) |
| RA `menuTrigger` (input/focus/manual) | open behavior | **Phase 1** — default `"input"` (type/click/ArrowDown, not bare focus); expose `@openOn` for `focus`/`manual` |
| RA `shouldFocusWrap` (wrap at ends) | `dRovingFocus` `wrap` arg (already supported, default clamp) | **Phase 1** — pass through as `@focusWrap` |
| RA `onKeyDown`/`onKeyUp`, `onFocus`/`onBlur` | — | **Deferred** — add on demand |
| RA/Base-UI controlled `open`/`onOpenChange` | `@onShow`/`@onClose` hooks | Have hooks; controlled `@open` **deferred** |
| RA `renderEmptyState` / Base-UI `Empty` | `@noResultsLabel` text only | **Phase 1** — expose an `:empty` *block* override, not just text |
| RA ListBox virtualization | `DLoadMore` pagination | **Declined v1** — pagination over virtualization; revisit only for huge client lists |
| RA `allowsCustomValue` | `@allowCreate` + `@createItem` (create row) | Have (create-row form); free-text-commit via `createItem` |
| RA `isRequired`/`isInvalid`/`validate`, `name`/`form`/`formValue` | — | **Parked → FormKit** (Phase 2) |

Net: the reference-prop deltas are deliberate deferrals plus small Phase-1 additions;
a deeper adversarial sweep (below) surfaced the more consequential gaps.

### Adversarial review — additional findings folded

**Correctness / completeness:**
- **`castInteger` is a latent equality bug already in the Phase-0 engine** (not a mere
  migration arg): `isSelected` and `#resolveOneSync` compare with strict `===`
  (`select-engine.js` ~219/493/497), so `@value="5"` against `id:5` neither highlights
  the row nor resolves the trigger label — it silently shows the placeholder.
  Reclassify as an **engine equality contract**: pull a normalized/coercing comparator
  (or a `@valueEquality` hook — select-kit's `castInteger` is the common case) into
  Phase 1; latent now only because the sole consumer is the controlled test harness.
- **Multi-select pipe-paste** (`|`-separated → bulk add; `multi-select-filter.gjs`) has
  no home and affects every multi-select (tags, groups, watched-words). Add a bulk
  `engine.append(values)` path + paste handling to the multi input (Phase 1).
- **In-list messages, not just form chrome.** select-kit renders max/min + validation
  as a collection *inside* the listbox (`ERRORS_COLLECTION`), and a **"filter for
  more"** sentinel row distinct from `DLoadMore` (`filter-for-more.gjs`, used by
  category-drop/tag-drop/group-chooser). Map both: `@maximum`/`@minimum` message renders
  in-list; add a "filter for more" sentinel for the category/tag families (Phase 3).
- **`expandedOnInsert`** (auto-open on mount; core consumer `d-access-control`) — add
  `"mount"` to `@openOn` (or a small `@autoOpen`).
- **`limitMatches`** (cap rendered rows), **`autofocus`** (focus closed trigger on
  mount) — low; a preset can bake `limitMatches` into `@load`; note, don't prioritize.
- Cleared as non-gaps: `triggerOnChangeOnTab` (dead code), Tab-commits (our
  Tab-never-selects is a deliberate improvement), Home/End (dRovingFocus already has
  them), type-to-jump on a static list (select-kit doesn't either — optional nicety),
  `mandatoryValues`/`hiddenValues`/`formName`/`focusAfterOnChange` (parked/subsumed).

**Chrome cross-product (resolve these undefined cells):**
- **Caret in a typeahead input** is opt-in and, when shown, a real toggle
  `<button aria-label>`, not a decorative glyph. `@caretIcon` should map select-kit's
  **`caretUpIcon`/`caretDownIcon` pair** (flips on open) or accept `false` to hide — a
  single static glyph loses parity.
- **`@clearable` in multi** = a distinct **clear-all** control (inline-end), coexisting
  with per-chip removes.
- **Trigger content order** (layout + RTL determinism), inline-start → inline-end:
  leading `@icon`, chips (multi), input, clear, caret.
- **`@allowCreate` + `static`** is impossible (create needs a filter term) → dev-warn/
  no-op, documented.
- **`@groupBy` edges**: the synthetic create row + `@specialItems` sit ungrouped/pinned.
  (Selected items now stay in-list with a checkmark, so groups no longer empty out from
  selection.)

**Naming (unify in the doc):** use `@openOn` consistently (the reconciliation table
said `menuTrigger`), noting it deliberately diverges from both FloatKit's `triggers`
array and React-Aria's `menuTrigger`; `@focusWrap` forwards `dRovingFocus`'s `wrap`
(keep `@focusWrap`, or rename `@wrap` to match the primitive); map select-kit's
`caretUpIcon`/`caretDownIcon` pair in the codemod table.

### Folded into Phase 1 (small, decided — not forks)

Close these select-kit / modern-lib customization gaps as part of "complete the
family":

- **`@clearable`** — clear/reset button in the trigger (`select-kit clearable`, shadcn
  `showClear`; chapoi). `DFilterInput @onClearInput` (already supported) → `engine.clear()`.
- **`@caretIcon`** — an open/closed **pair** that flips: `{ open, closed }` (default
  `{ open: "angle-up", closed: "angle-down" }`), a single string for both, or `false`
  to hide (select-kit's `caretUpIcon`/`caretDownIcon`). In `typeahead`, when shown, it
  is a real toggle `<button aria-label>`, not a decorative glyph.
- **`@icon`** — a leading trigger icon (`select-kit icon`/`icons`).
- **`@disabled` / `@readonly`** — whole-select disabled/read-only (`select-kit
  disabled`; React-Aria `isDisabled`/`isReadOnly`); needed for FormKit.
- **`@onShow` / `@onClose`** — open/close hooks (`select-kit onOpen`/`onClose`).
- **`@placement` / `@offset`** — position passthrough to the float primitive.
- **Auto-highlight** the first match so Enter commits the obvious choice (React-Aria).
- **`@focusWrap`** — pass through `dRovingFocus`'s existing `wrap` arg (default clamp);
  arrow-key wrap at list ends (React-Aria `shouldFocusWrap`).
- **`@openOn`** — open behavior: default `"input"` (type/click/ArrowDown, not bare
  focus); `"focus"`/`"manual"` opt-in (React-Aria `menuTrigger`).
- **`:empty` block override** — let a consumer render the no-results/empty content,
  not just set `@noResultsLabel` text (React-Aria `renderEmptyState`).
- **`@minChars`** — minimum query length before a *server* search fires (default 0);
  below it, show a "type to search" prompt instead of querying (select-kit's
  `skipSearch`/`eagerCompleteSearch`, e.g. user search). Plus optional `@debounceMs`
  (override the derived debounce for slow endpoints) and a `validateCreate(term)` hook
  on `@allowCreate` (reject invalid create entries, e.g. tag rules).

### Parked (later phase, mapped — not dropped)

- **`@maximum`/`@minimum`, mandatory/hidden values** → Phase 1 with multi/chips.
- **Loading-state granularity** (`loading` vs `filtering` vs `loadingMore`) → Phase 1
  with `DLoadMore` (React-Aria `loadingState`).
- **`castInteger`/value coercion** (string-id vs number-id compare via `valueField`) →
  Phase 2 migration concern.
- **Native `name`/form submit, `isInvalid`/validation chrome** → FormKit (Phase 2).
- **Full trigger/row component override** (`headerComponent`/`modifyComponentForRow`)
  → `:selection`/`:item` blocks cover content; revisit only if a picker needs a full
  component/behavior override.

### Migration-parity note

`:item`/`:selection` are our `modifyComponentForRow`/`headerComponent` equivalent;
`@specialItems` + `@placeholder` cover `none`/`autoInsertNoneItem`; `item.onSelect`
covers action rows; `@allowCreate` covers `allowAny`. The only select-kit behaviors
with no home yet are the "parked" ones above — none block Phase 1.

### Documentation & progress tracking (deliverable)

This plan is long; keep it usable across the multi-phase effort via three in-repo
artifacts (working docs in the worktree; committing them is a per-commit call — the
master RFC was kept local for Phase 0):

1. **Master reference — `SELECT-KIT-REPLACEMENT-RFC.md`** (worktree root; exists but is
   now stale). Fold this whole refinement into it — Decisions 1–6, the Decision-1b
   state model, batch/fallback/normalization, windowing, tokenization, the
   reconciliation table, and the adversarial findings — so it mirrors this plan. Single
   source of truth for the **design**.
2. **Per-phase tracker docs — `docs/select-kit-replacement/PHASE-0.md … PHASE-5.md`**
   (one per roadmap phase). Each is **lean, not a copy of the RFC**: a **goal**, a
   **task checklist with status** (☐ pending / ◐ in-progress / ☑ done), **exit
   criteria**, and **cross-links** to the relevant RFC decision sections. `PHASE-0.md`
   is retro-filled (0a–0g mostly done; the TS conversion and the typeahead-default
   rework are the pending items). The checklist is updated **as we execute**, so state
   is always visible.
3. **Index — `docs/select-kit-replacement/README.md`**: the phase list with a one-line
   status + link each, so "what's pending vs done" is answerable at a glance.

*Reconcile the roadmap numbering:* this plan's roadmap is Phases 0–5, while the Dev RFC
topic #187302 lists a finer **0–11**; the per-phase docs follow **this plan's** phases
and must note how the Dev breakdown maps in (so the public roadmap and our trackers
don't drift). Keep the master RFC and the trackers in sync as decisions change. The
public Dev topic is a separate, outward-facing update (only if requested).

## Mechanism & invariants (how select-kit works today; what we must preserve)

- **Public surface**: angle-bracket tags (`<ComboBox>`, `<CategoryChooser>`,
  `<TagChooser>`, `<UserChooser>`, …) + direct imports from
  `discourse/select-kit/components/…` **and** the bare legacy `select-kit/…`
  specifier (both resolve via `select-kit/compat-modules.js`).
- **Extension**: `api.modifySelectKit(identifier).{appendContent, prependContent,
  replaceContent, onChange}` (`select-kit/lib/plugin-api.js`) — **four** ops,
  keyed on `pluginApiIdentifiers`, which accumulate down the class chain (a
  callback on `"combo-box"` fires for every combo-box-derived select). Plus
  `registerComposerAction` / `addComposerToolbarPopupMenuOption`,
  `addUserSearchOption`/`CUSTOM_USER_SEARCH_OPTIONS`, and the `resolveComponent`
  string-name path.
- **Row-action escape hatch already exists**: `select-kit.js` runs
  `item.onSelect(this.selectKit, item)` and returns *without* selecting/closing —
  the exact primitive the AI RFC (#185600) wanted.
- **Invariants to hold**: (1) no third-party breakage overnight — old tags,
  imports, and `modifySelectKit` extensions of *core's* selects must keep working;
  (2) conservation of the four content ops' ordering semantics (prepend, then
  append, then replace-wins); (3) selection correctness (single closes + no
  over-select; multi toggles); (4) **accessibility must be a hard gate, not a
  follow-up**.

## Chosen approach — Hybrid (and why the alternatives lost)

A plain, DOM-free **`SelectEngine`** class owns the internal UI state (filter,
result loading, resolved-item cache) and the selection *logic*, and drives the
foundations. **The value is controlled** — the parent owns `@value`; the engine
derives `isSelected`/display from it and emits `@onChange(nextValue, item|items)`,
keeping no internal selection state (matching FormKit's `@value`/`@field.set`). The **public API is one component, `DSelect`** — single-select by
default, **multi-select via `@multiple`** (a capability flag the engine already
models, *not* a separate component) — plus domain presets (`DCategorySelect`,
`DTagSelect`, …) that pass `@multiple` through, so one preset serves both arities.
`DMultiSelect` survives only as a thin `@multiple={{true}}` alias for its existing
name/consumers. Presets take `@load` + a `:item` block. The composition parts (Filter /
Results /
Option) stay **internal** — core component authors compose freely from them, but
they are not a public contract.

- **vs. Config-driven family** (engine *is* the component): rejected because the
  base reinflates with args as specialized pickers accumulate — structurally
  recreating select-kit's god-component failure mode — and its state logic is only
  testable through rendering. Its merit (one concept, smallest surface) is real
  but loses to long-term maintainability.
- **vs. Headless + public parts**: rejected because publishing the parts creates a
  large permanent surface, invites inconsistent hand-assembled selects, and lets a
  consumer render raw results that **bypass the transformer pipeline and silently
  drop plugin rows**. Its merit (max flexibility) is retained *internally* —
  core wrappers use the parts; we can promote them to public later if a real need
  appears (a one-way door in the safe direction).

Hybrid keeps the shared core tiny (specialization goes into thin wrappers, or a
subclassed/composed plain engine — both unit-testable), makes the public surface
small and safe, and makes plugin-extensibility guaranteed rather than optional.

## Extension model — transformers (not a bespoke registry)

Use the **standard transformer API**, which already models this exact shape:
`composer-actions-new.gjs` extends a dropdown of items via
`applyValueTransformer("composer-actions-content", …)` +
`applyBehaviorTransformer("composer-actions-on-select", …)`, extended by
`discourse-post-voting`.

- **Content** → a value transformer `applyValueTransformer("select-content",
  items, ctx)`. Plugins prepend/append/replace by returning a modified array.
- **Selection side effects** → `applyBehaviorTransformer("select-on-change",
  defaultFn, ctx)`.
- **Action items** (run a callback instead of selecting) → an `item.onSelect(engine,
  item)` closure on the item (plain data, authored by whoever injected it; the
  engine honors it before selecting/closing).
- **Transformer names are frozen at boot** (`app/lib/transformer.js` +
  `registry/transformers.js` + the `freeze-valid-transformers` init), so we use a
  **fixed generic name pair with the select's identifier(s) in `ctx`** (the
  `composer-actions-content`/`context.action` idiom). Register `select-content`
  (value) and `select-on-change` (behavior) in `VALUE_TRANSFORMERS` /
  `BEHAVIOR_TRANSFORMERS`; plugins branch on `ctx.identifiers`.

### Legacy `modifySelectKit` bridge (the hard part — findings folded in)

Re-implement `api.modifySelectKit(id).{append,prepend,replace,onChange}` on top of
the new pipeline so third-party extensions of *core's* selects keep firing after
core swaps to the new components. The review surfaced non-trivial fidelity
requirements the bridge **must** meet:

1. **Preserve the 3-phase ordering** (all prepends → all appends → replace-wins)
   *within* the bridge; do not lean on transformer registration order (which is
   global and would flip cross-plugin ordering). Keep bridged callbacks in their
   own ordering stage, separate from native `select-content` registrations.
2. **Stable per-instance facade**: memoize exactly **one** `legacyComponentFacade`
   per engine instance — the AI suggester keys a `WeakMap` on the instance; a
   fresh facade per call makes every state lookup miss.
3. **The facade must be `EmberObject`-backed** (callbacks use `.get()`/`.set()`,
   `selectKit.select/close/isLoading`, `component.action`, nested paths), not a
   plain object — and must expose `.element` + owner (the AI content callbacks call
   `getOwner(component)` and `component.element.closest("#reply-control")` to build
   their context; without these the AI row silently never renders). This means the
   value-transformer `ctx` for bridged selects must carry `element`/owner —
   an explicit, documented exception to "plain ctx."
4. **`onChange` must reconstruct the selected-item argument** (old signature passes
   `(component, value, items)`; the behavior-transformer ctx must surface `items`).
5. **Keep an array of identifiers** (`["combo-box", "category-chooser"]`), not one
   string, to preserve base-class fan-out that the core `api-test.gjs` asserts.
6. **Suppress double-registration**: `composer-actions` already dual-registers
   `modifySelectKit` *and* the transformer; the bridge must not forward identifiers
   that already have a native transformer path (else rows insert twice).
7. **Emit a deprecation on every use** — the bridge is *not* a silent shim. Each time
   a `modifySelectKit(id)` callback fires through a new component it emits a
   `deprecated(...)` under a dedicated id (`discourse.select-kit.modify-select-kit`)
   naming the replacement (`api.registerValueTransformer("select-content", …)` /
   `"select-on-change"`). This nudges the author **and** gives the deprecation
   collector a real per-use signal, so the bridge can be removed once usage hits zero.

## Library shape — taxonomy, naming & file layout

The family lives under `frontend/discourse/app/ui-kit/` (flat `d-*` convention, no
barrel/index; multi-part components use a `d-<name>/` folder per the
`d-icon-grid-picker/` and `d-otp/` precedent). Layout:

- `app/ui-kit/select/` — the machinery: `select-engine.js` (headless class), the
  transformer registration, and a `-internals/` subfolder (the leading-dash "private,
  don't import directly" marker already used in `app/lib/blocks/-internals/`) holding
  the composition parts: combobox filter, `role="listbox"`, `role="option"`,
  trigger, and multi-select chip.
- Public entries as flat `d-*` modules so `ui-kit-shims.js` can alias them:
  `d-select.gjs` (the one combobox; arity via `@multiple`) and `d-multi-select.gjs`
  (a thin `@multiple={{true}}` alias kept for its existing name/consumers). Presets
  (`d-category-select.gjs`, `d-tag-select.gjs`, …) are flat `d-*` too — thin
  compositions of the engine + a `:item` block that pass `@multiple` through.
- **Name collision & native deprecation**: `d-select.gjs` currently is the native
  `<select>` wrapper (~12 consumers). Rename it `d-native-select.gjs`
  (`DNativeSelect`) with a shim alias and **mark it deprecated** (new deprecation
  id), freeing `DSelect` for the combobox. For coherence there is **one** select
  family: `DSelect`'s *simple/static mode* (see Interaction modes) covers the short
  static lists native `<select>` was used for, so `DNativeSelect` is a migration
  bridge, not a kept peer — FormKit's plain `select` control and the ~12 consumers
  migrate to `DSelect`.

## Consolidating the ad-hoc components

| Existing (ui-kit) | Disposition |
|---|---|
| `DSelect` (native `<select>`, ~12) | **Deprecate.** Rename → `DNativeSelect` (deprecated shim) for the window; `DSelect`'s simple/static mode replaces it; FormKit plain `select` control + the ~12 consumers migrate to the family |
| `DMultiSelect` (DMenu+DDropdownMenu, hand-rolled async/keyboard, ~8) | **Becomes a thin `@multiple` alias of `DSelect`** on the engine (roadmap P1) — name/consumers survive, but the logic is one component; retires the hand-rolled debounce, keyboard, and inline skeleton |
| `DIconGridPicker` (DMenu+DAsyncContent grid, ~22) | Re-home on the engine as the grid variant; migrate loading to `DSkeleton` and announcements to the `a11y` service |
| `DDropdownMenu` (`<ul>` action menu, ~91) | **Stays** as action-menu chrome; the select family renders its own `role="listbox"` (not `DDropdownMenu` — whose `<ul>` is what the current `DMultiSelect` invalidly nests `<div>`/`<li>` into) |
| `DFilterInput` (~43) | **Reused** as the combobox filter input |
| `DAutocompleteResults` + `d-autocomplete` modifier (~13) | **Separate engine** (inline @-mention typeahead), out of scope for the select family now; long-term its result list could share the `-internals` listbox/option parts — flagged, not committed |

There are two dropdown engines in the codebase — FloatKit `DMenu` (declarative) and
the imperative `d-autocomplete` modifier. The select family standardizes on `DMenu`.

## Data strategies — async is first-class (client-only is the degenerate case)

**Async is a first-class capability, not a bolt-on.** The engine is async-native: its
core is one loader that models loading / content / empty / error, debounce, request
cancellation, and out-of-order safety for *every* select. A client-only list is
simply the case where the source resolves **synchronously** — the same loader, not a
separate path. (Contrast select-kit, whose base is a synchronous `content` array and
whose async pickers each override `search()` and hand-toggle an `isLoading` flag,
with no built-in error, cancellation, or race handling.) Two sources, one loader:

- **Client-only** (`@options` / `localContent`: a sync array or a `() => array`) —
  the engine filters synchronously in JS on each keystroke; the source returns a
  **raw array**, so there is **no pending phase, no skeleton, instant**. For
  `list-setting`, static enum settings, preloaded categories on small sites.
- **Server-backed** (`@load` / `loadFn(filter, { signal })` → Promise) — the source
  returns a **promise**, so `DAsyncContent` shows loading → content/error, debounced,
  with request cancellation. For tag/user/category search.
- **Dual-mode** presets (e.g. `category-chooser`: async on lazy-load sites,
  preloaded on small ones) choose the source at construction — a single ternary,
  no special-casing in the engine.
- **Large sets**: `DLoadMore` inside the listbox for paginated/infinite loading
  (a capability select-kit had; wired at the server-backed path).

### Data layer — one unified path on an improved `DAsyncContent`

Both sources normalize, **once at construction**, into a single
`source(filter, { signal }) → items[] | Promise<items[]>` closure — local returns a raw
array, server returns a promise, dual-mode returns either per call. The component
feeds that one closure straight to `DAsyncContent`, so there is **one template, no
local/server branch**:

```gjs
<DAsyncContent @asyncData={{@engine.source}} @context={{@engine.loadContext}}
               @debounce={{@engine.isAsync}}>
  <:loading><DSkeleton … /></:loading>
  <:content as |value|>{{! engine.buildItems value → <ul role="listbox"> }}</:content>
  <:empty>…</:empty>
  <:error as |e retry|>…</:error>
</DAsyncContent>
```

**We strengthen `DAsyncContent` rather than side-step it** — two small,
backward-compatible additions that benefit every async consumer, not just selects:
1. **Accept a synchronous return.** Today the `@asyncData` function *throws* if it
   returns a non-promise (`d-async-content.gjs:106-110`). Instead, wrap a non-promise
   directly in `TrackedAsyncData`, which **resolves it synchronously** (verified:
   `tracked-async-data.js` — `if (!isPromiseLike(data)) this.#state.data =
   ['RESOLVED', data]`). With `@debounce` off, a local source then renders content
   **with no pending phase and no skeleton flash** — the sync fast-path, inside the
   shared primitive. (Backward-compatible: turns a throw into a success.)
2. **Thread an `AbortSignal`.** `DAsyncContent` creates a controller per fetch, calls
   `asyncData(context, { signal })`, and aborts the superseded request on context
   change / teardown — the cancellation it lacks today. (Backward-compatible:
   existing functions ignore the extra param.)

`DAsyncContent` already discards a stale `TrackedAsyncData` when `@context` changes,
so **out-of-order display safety is inherited**; the added signal covers the network.
`@debounce={{engine.isAsync}}` (a value, not a branch) keeps local filtering instant
and debounces server keystrokes.

**First-class async guarantees** — now all delivered by the shared foundation:
- **Debounce** server keystrokes; **cancel** superseded requests + **abort** on
  teardown (the new signal); **out-of-order safety** (stale `TrackedAsyncData`
  discarded).
- **Async selection resolution**: when the bound value is an id whose label isn't in
  the current results (a preselected category/user/tag), the engine resolves its
  display label through the same `source` — a core step, not the ad-hoc per-picker
  lazy-load select-kit hand-rolls (`category-chooser.js:29-43`).
- **Re-run with an unchanged filter** (the AI spinner→results flow): the engine bumps
  a nonce inside `loadContext` so `DAsyncContent` recomputes even when the filter
  string is identical (or a small `@reloadKey` arg added to `DAsyncContent`).
- **Retry** on error via the `:error` block's yielded retry; loading/empty/error are
  `DAsyncContent` states, not manual flags.

The engine owns filter / result loading / `buildItems` / keyboard (the value is
controlled — see Value model); **all async state stays in `DAsyncContent`**, improved once for everyone (e.g. `DIconGridPicker` gains
cancellation for free). This keeps the library on solid, composable foundations
rather than a per-component hand-roll (the sin of select-kit and today's
`DMultiSelect`).

### Selected-value resolution — fetch-to-display (first-class)

A bound value is often just an **identifier**; showing the selected item in the
trigger (or as chips) may require fetching its full record. The library does this
**automatically** so a picker never flashes a raw id — a general capability exercised
by, not shaped by, the topic-picker use case
(`~/.claude/handoffs/discourse/2026-07-06-dtopicselect-topic-picker.md`) and the
per-picker lazy-loads select-kit hand-rolls (`category-chooser.js:29-43`):

- `@resolveValue(value, { signal }) → item | Promise<item>` (multi: `@resolveValues`)
  — resolves id(s) → displayable item(s) on the same improved `DAsyncContent` (sync
  fast-path + abort + cache).
- **Escape hatch `@selected` / `@selectedItems`** — when the caller already holds the
  full object (e.g. an invite that embeds its topic), pass it and **no fetch happens**
  (synchronously resolved, no flash).
- **Content-only skeleton in the trigger** while resolving: the frame / caret / clear
  stay; only the value text is a `DSkeleton @variant="text"` (each unresolved chip in
  multi). Overridable via `:selectionLoading`.
- **Cache + short-circuit**: picking from the open list feeds the full item straight
  in (no resolve); resolved values are cached (reopen / re-render never refetch); a
  value already in the current results resolves synchronously.
- **Deleted / restricted / rejected → a synthetic `__unresolved` fallback item**
  (never hidden, never a bare raw id) — see "Selection resolution — batch, fallbacks,
  and model normalization" in Decision 1b. A held value is always represented and
  clearable; batch resolution (`@resolveValues`) is required for multi.

This is a *second async surface, independent of list-loading*: the **trigger**
resolves the selected value while the **dropdown** loads options — both on the
improved `DAsyncContent`.

### Interaction modes (orthogonal to data source)

The native `<select>` is deprecated, so `DSelect` covers three trigger variants via
`@variant` (default `typeahead`) — see **API refinement › Decision 1** above for the
full rationale and the per-breakpoint FloatKit details:

- **`typeahead`** (default, searchable): the trigger IS a `role="combobox"` input;
  `dRovingFocus` **`active` mode** moves a virtual highlight while focus stays in the
  input (desktop) or in the modal/sheet input (mobile).
- **`button`** (variant, searchable): button trigger + in-panel `DFilterInput`, for
  rich value display (badge/avatar) or menu-style pickers.
- **`static`** (variant): **no filter input**; the listbox itself takes focus and
  `dRovingFocus` **`focus` mode** (real roving tabindex) navigates. No
  `aria-activedescendant` mobile-SR weakness, so short static selects are strongly
  accessible on mobile for free — the native-`<select>` replacement.

## States — loading, empty, error, create, filter

- **Loading — two independent surfaces, both `DAsyncContent`-driven**:
  - *List / results* (dropdown fetching options): placeholder **rows** in the
    listbox. `:loadingItem` renders one placeholder row, repeated `@skeletonCount`
    times (default ~5), so a **compound row** (e.g. a `circle` avatar + `text`
    title/subtitle bars) mirrors the real `:item`; `:loading` overrides the whole
    region. Default = a single `DSkeleton @variant="text"` row. **Retire the bespoke
    inline `Skeleton` in `d-multi-select.gjs`** and the icon-picker's plain
    `.spinner`; standardize on `DSkeleton` (structural convention, `topic-card.gjs`).
  - *Trigger / chips* (resolving the selected value): the content-only skeleton from
    Selected-value resolution above — just the value text, not the whole combo.
- **Empty** (`DAsyncContent`'s `:empty`): two cases — "no data" and "no matches for
  the current filter" — each a `role="status"` message routed through
  `this.a11y.announce(…, "polite")` (not a hand-rolled live region). Uniform for
  local and server.
- **Error** (`DAsyncContent`'s `:error`, server only): the block's inline
  `DFlashMessage` plus its yielded retry; announced.
- **Create-on-the-fly**: ui-kit has **no** precedent — port select-kit's
  `allowAny`/`createContentFromInput`. The engine appends a synthetic
  `{ __create: true }` row when the filter is non-empty and matches no exact
  option; the `:item` block renders "Create: %{term}". Selecting it adds the typed
  value (tags, list-setting free text).
- **Filter**: the combobox input is `DFilterInput` (`@value`, `@filterAction`,
  `@onClearInput`, `@icons`); client path filters `localContent`, server path
  re-runs `loadFn` — both keyed off the same engine filter token that also feeds
  `dRovingFocus`'s `itemsKey`.

## Authoring a new select — DevEx

The payoff of the hybrid is that adding a select is *composition*, not subclassing. A
new specialized select is a thin `.gjs` wrapper over `DSelect` (arity via `@multiple`,
not a second component) that supplies a **source** and domain args. Plain rows and
selections need no blocks: both fall back to `@labelField` (`name` by default). Add
`:item` and/or `:selection` only when that surface needs custom markup. The wrapper
inherits filtering, all async state, keyboard, ARIA, positioning, and transformer
extensibility for free.

### The source contract (how sync/async stays ergonomic)

An author declares *where rows come from*, never *how to fetch-and-track* them:
- `@options` — an array or `() => array`. Client-only; the engine filters it
  (`@filterBy` = a field name or `(item, term) => boolean` to customize matching).
- `@load` — `(filter, { signal }) => items[] | Promise<items[]>`. The general form:
  **return an array for a sync/client source, a promise for a server source** — and a
  **dual-mode** select is a *single* function that returns either per call
  (`return this.lazy ? this.server(filter, { signal }) : this.local(filter)`). No
  second code path, no `isLoading` flag, no try/catch — the engine derives
  loading/empty/error/retry, debounces, cancels via `signal`, and guards races.

(`@options` is just sugar for `@load={{() => array}}`; both normalize to the one
internal `source` closure from the Data layer section.)

### A new select, end to end (contrast with select-kit)

```gjs
// d-user-select.gjs — ONE preset, single OR multi via @multiple, ~15 lines
export default class DUserSelect extends Component {
  @service store;
  #search = (filter, { signal }) => this.store.searchUsers(filter, { signal });
  <template>
    <DSelect @identifier="user-chooser" @multiple={{@multiple}}
             @value={{@value}} @onChange={{@onChange}}
             @load={{this.#search}} @labelField="username">
      <:item as |user|><UserRow @user={{user}} /></:item>
      <:selection as |user|>{{user.username}}</:selection>
    </DSelect>
  </template>
}
```

**Arity is a flag, not a component**: `<DUserSelect />` is single,
`<DUserSelect @multiple={{true}} />` is multi — one preset, no fork. (`@value` is
scalar when single and an array when multi; `:selection` renders chips only in multi;
the engine's `multiple` flag drives close-on-select and value shape.) Compare
select-kit: a subclass of `MultiSelectComponent` overriding `search()` and
`modifyComponentForRow()`, a `@selectKitOptions({…})` bag, a bespoke row component
class, and manual `isLoading` toggling.

### What the author never writes (owned by the engine/parts)

Fetch state machine · loading skeleton · empty/error/retry UI · debounce · request
cancellation · out-of-order guarding · preselected-value resolution · filter input ·
keyboard nav · combobox/listbox ARIA · overlay positioning · mobile modal.

### The authoring surface (blocks & args)

- **Sources**: `@options` / `@filterBy`, or `@load`; `@minChars` (min query length
  before a server search fires) / `@debounceMs`.
- **Presentation**: optional `:item` (each option) and `:selection` / `:trigger`
  overrides; when omitted, option rows, triggers, and chips render `@labelField`
  (`name` by default). Also `:empty` (override); `:loadingItem` (one compound
  placeholder row, repeated `@skeletonCount`)
  or `:loading` (whole-region override); `:selectionLoading` (trigger/chip skeleton
  while the selected value resolves); `:unresolved` (fallback for a 404/restricted/
  omitted id — defaults to `:selection` branching on `item.__unresolved`).
- **Values**: `@value` (controlled source of truth, applied immutably) +
  `@onChange(nextValue, item|items)`, `@valueField` / `@labelField` (the single source
  of truth for identity/label — items are normalized, no `id` assumption). FormKit
  forwards `id`/`name`/`disabled`/`aria-*` onto the combobox input.
- **Behaviors**: `@allowCreate` + `@createItem`, `@specialItems`, `@resolveValue` /
  `@resolveValues` + the `@selected` / `@selectedItems` escape hatch (fetch-to-display
  of a bound id — see Selected-value resolution), `@identifier` (transformer extension
  key), `@variant` (`typeahead`|`button`|`static`, default `typeahead`; replaces the
  Phase-0 `@searchable`) / `@multiple`, `@disabled` / `@readonly`, `@onShow` /
  `@onClose`.
- **Chrome** (see API refinement): `@clearable`, `@caretIcon` (customize/hide),
  `@icon` (leading), `@placement` / `@offset`, `@groupBy` (section headers),
  `@openOn` (open behavior), `@focusWrap`. (Windowing is automatic — no `@pageSize`:
  client uses an internal chunk, server auto-detects page size; hard `MAX_RENDERED` cap.)

### Testing DevEx

The engine is a headless class → unit-test source/value/filter logic with
no render. A preset inherits the base's a11y acceptance tests, so a new select needs
only a small render test for its `:item`/domain wiring — not a re-test of
keyboard/ARIA/async.

## Visual design & styling precautions

The family is intentionally **not** a new visual language — it reuses the existing
`DMenu` chrome, `DDropdownMenu`/`DFilterInput`/`DSkeleton` look, and theme tokens, so
it matches the icon picker and FormKit menu by default and inherits their polish.

- **Fully tokenized — expose a component custom-property surface, don't just consume
  the palette.** Mirror the existing `--d-button-*` convention
  (`--d-button-default-bg-color`, `…--hover`, `…-border`, `…-icon-color`, radius, …):
  define a `--d-select-*` (combobox) token surface — trigger/option/chip bg · text ·
  border · icon · radius, per-state `--hover`/`--focus`/`--selected`/`--disabled`, and
  layout tokens (gap/padding/max-height) — **defaulting** to the theme palette
  (`--primary`/`--d-hover`/`--primary-low`/`--tertiary`/`--primary-medium`). Themes and
  presets then restyle **via tokens**, not selector overrides. No hard-coded colors
  (select-kit shipped a `#fff` fallback). Fresh `d-select__*` BEM classes, not the
  ported `.select-kit-*` contract. **Refactor the Phase-0 `d-combobox.scss`** (which
  currently reads raw palette vars) onto this token surface.
- **Design-conformance** was reviewed at plan time (sanctioned primitives, BEM,
  FloatKit/FormKit, ui-kit reuse, Sentence case). A `discourse-visual-review` pixel
  gate runs at implementation across **light/dark themes and mobile** (dark-mode
  regressions bit select-kit's a11y rollout).
- Reduced-motion is honored for free via `DSkeleton` (shimmer only under
  `prefers-reduced-motion: no-preference`).

## Accessibility contract (hard gate — the headline requirement)

Historical select-kit a11y failures all trace to five root causes; the new library
makes each **structurally impossible**:

| Root cause (historical) | Structural fix |
|---|---|
| Typing "into a button"; no real input | A real `role="combobox"` **text input** (`DFilterInput`) is the filter |
| Wrong ARIA (`role="menu"`/`menuitemradio`) | WAI-ARIA **editable-combobox + `role="listbox"`/`option`** pattern |
| Focus via side-effects/hacks | Managed focus from FloatKit/DModal + hardened `dRovingFocus`; **no hand-rolled focus** |
| Keys overloaded (Tab selects + opens modal) | Tab only moves focus; selection is Enter/click; no surprise actions |
| Async-then-focus (iOS rejects) | Focus the input **synchronously on open**, before async load resolves |

**ARIA ownership** (who sets what):
- Filter input (`DFilterInput`, **not** `DTextField` — the latter's
  `attributeBindings` silently drops combobox ARIA): `role="combobox"`,
  `aria-expanded`, `aria-controls={listboxId}`, `aria-autocomplete="list"`,
  `aria-activedescendant`, accessible name.
- Results: real `<ul role="listbox" id={listboxId}>` (fixes the current
  `d-multi-select` `div-in-ul`/`li-under-div` invalidity),
  `aria-multiselectable="true"` for multi.
- Option: `<li role="option" id={stableId} aria-selected>`. **The engine owns
  `aria-selected`** (`dRovingFocus` deliberately never sets it). Disabled options
  carry `aria-disabled="true"` (already skipped by the modifier's `#isUsable`).

**Focus & keyboard**: synchronous input focus on open; Escape closes + returns
focus to trigger; chip remove is a real `<button aria-label="Remove %{name}">`
with focus moved to the next chip/input after removal; Tab never selects.

**Screen-reader announcements**: use the **`a11y` service**
(`this.a11y.announce(msg, "polite")`) — the app-wide live-region host
(`components/a11y/live-regions.gjs`) renders the region once, so components must
**not** hand-roll `aria-live` and must **never** use `role="alert"` per keystroke
(select-kit's noise bug). Announce result counts (debounced), empty state, and
selection changes politely. **Migrate `DIconGridPicker` off its inline
`aria-live` region (`content.gjs:401`) to the service** as part of this work.

**Mobile**: on mobile DMenu renders inside `DModal`. Simple/static selects already
use `dRovingFocus` `focus` mode (real focus), which is solid on mobile SRs. The open
concern is **searchable** comboboxes: `aria-activedescendant` (virtual focus) has
weak iOS-VoiceOver / Android-TalkBack support, so the searchable mobile path likely
needs a **real-focus fallback** — a fork to validate on-device. The live region must
be within the announced context.

## The `dRovingFocus` blocker (must fix first — verified)

`dRovingFocus`'s `active` (combobox) mode is **not combobox-ready** and has **zero
production users** (untested). Verified in `d-roving-focus.js`: the editable-target
guard (line 127) *deliberately exempts* active mode; `Space` and `Enter` both call
`onActivate` + `preventDefault()` whenever `current >= 0` (lines 172–178), and
`#currentIndex` floors to `0` in active mode (line 324) — so **a space can never be
typed into the filter**. `Home`/`End` (166–170) and, at the default `grid`
orientation, `Left`/`Right` (146–164) are also hijacked from the caret, and
`onActivate` receives a DOM element, not a data item (line 176).

Because `dRovingFocus` is a pre-release modifier we own (and is **the only
dependency not yet on `main`**), we harden it in this work:
- When the controller is a text input, do **not** intercept printable keys,
  `Space`, `Home`/`End`, or `Left`/`Right` — reserve only `ArrowUp/Down`, `Enter`,
  `Escape` (+ APG combobox extras).
- Represent "no active item" (don't floor to 0), so `Enter` with nothing
  highlighted can submit/create rather than pick item 0.
- Resolve activation without an element→item map: `onActivate(el)` calls `el.click()`,
  and each option's own click handler (closing over its item) runs `engine.activate(item)`
  (which honors `item.onSelect`) — the topic-picker use case validates this pattern.
- Ship dedicated keyboard unit tests (no existing safety net).

## Migration strategy — deprecate + ban from core/bundled; no deletion

- **Introduce new components**; **freeze select-kit in place** (untouched, so its
  contract is literally identical for third parties); **codemod core + bundled
  plugins** off the old tags; **bridge `modifySelectKit`** into the new pipeline;
  deprecate everywhere. **Select-kit is NOT deleted** — third-party customizations in
  the wild depend on it, so it stays available (deprecated) indefinitely.
- **Every modernized component is deprecated, per-component.** When a facade renders
  the new component under an old tag (`<ComboBox>`, `<CategoryChooser>`, …) — or an
  old `select-kit/components/…` module is imported — it emits its own
  `deprecated(...)` under a component-scoped id (e.g.
  `discourse.select-kit.combo-box` → "use `<DSelect>`"), `since` = the current
  date-version. This is the real *component-usage* signal — used to confirm core +
  bundled plugins have migrated and for third-party telemetry, **not** to schedule a
  deletion.
- **Done = core + bundled plugins fully off select-kit, and *banned* from reaching for
  it again** — enforced by a lint rule (`no-restricted-imports` for `select-kit/*` +
  a template rule for the old tags) scoped to core `app/`, `admin/`, and bundled
  `plugins/`, so new code can't reintroduce it. Reaching that requires: (a) porting
  the **~19 bundled plugins that *subclass* select-kit** or use
  `selectKitOptions`/`modifyComponentForRow` (not codemoddable — e.g.
  `plugins/chat/.../chat-channel-chooser.js`,
  `discourse-assign/.../assign-actions-dropdown.js`,
  `discourse-activity-pub/.../*-dropdown.js`, `discourse-workflows`,
  `discourse-adplugin`); (b) rewriting the test infra hard-keyed to `.select-kit-*`
  classes — the Ruby page object `spec/system/page_objects/components/select_kit.rb`
  (~67 dependent specs) and `tests/helpers/select-kit-helper.js` (~54 acceptance
  files). Select-kit itself, its SCSS, `compat-modules`, the `modifySelectKit` bridge,
  and `DNativeSelect` all **remain** (deprecated) so third parties keep working.
- **Codemod**: no codemod harness exists in-repo — it must be built
  (`ember-template-recast` for templates, jscodeshift for imports), handle **both**
  import specifiers, and replicate select-kit's runtime arg-alias table. High-volume
  resistant patterns: `@options={{hash …}}` (~161 files) → flat args; static
  `@content` (~94 files) → async `@load`; string `headerComponent`/etc. The codemod
  is **published** so third parties can run it themselves.
- **CSS**: the ~1,495 lines under `common/select-kit/` are rewritten as fresh BEM
  with theme tokens (not reused); the old SCSS stays frozen alongside old JS for
  third parties.

## Phase 0 — build now (in the worktree)

Scope chosen: **harden the primitive + build a new component beside `DMultiSelect`;
defer the in-place `DMultiSelect` rewrite.**

0a. **Logistics**: create worktree `~/discourse/core/worktrees/select-kit-rework`
   off `main`; **port from `feature-wireframe-plugin` the two dependencies not yet on
   `main`**: `d-roving-focus.js` (+ test) and `d-skeleton.gjs` (+ `d-skeleton.scss` +
   test). Coordination note: their first landing on `main` is via this branch; the
   editor branch later rebases and drops its copies — avoid diverging edits.
   Add the Worktrees rule to `CLAUDE.local.md`. Save this RFC as a markdown doc
   inside the worktree.
0b. **Harden `dRovingFocus` active mode** for text comboboxes (per the blocker
   section) + keyboard unit tests.
0c. **Improve `DAsyncContent`** first (both backward-compatible, with tests): accept a
   synchronous `@asyncData` return (resolve immediately, no pending) and thread an
   `AbortSignal` into `asyncData(context, { signal })` with abort-on-supersede/teardown.
0d. **`SelectEngine`** (plain class) that **feeds** the improved `DAsyncContent`:
   normalizes both inputs into the single `source(filter, { signal })` closure; owns
   only `filter` + reload `nonce` + a resolved-item cache. The **value is controlled**
   — the engine reads `@value` via a `getValue` thunk and derives `isSelected`/display;
   `activate` (honors `item.onSelect`), `select`/`deselect`/`clear` compute the next
   value and emit `@onChange(nextValue, item|items)` (no internal selection). Plus
   `buildItems`, `resolveSelection` (the id→item ladder feeding trigger / chips /
   `onChange`), and `reload` (bumps the nonce so an unchanged-filter re-run still
   re-fetches — the AI spinner→results flow).
   `DAsyncContent` owns loading/empty/error/abort. Reads `site`/`currentUser`/`i18n`
   via constructor args, not owner injection where possible. **Expose only frozen
   projections / query methods — never the live engine** (honor the "no raw mutable
   state" rule); parts receive derived values + callbacks.
0e. **Transformers**: register `select-content` (value) + `select-on-change`
   (behavior); implement `buildItems` to run them (identifiers in ctx). Implement the
   **`modifySelectKit` bridge** with all six fidelity requirements above.
0f. **One new component, `DSelect`** — built in single mode this cycle (rename native
   `DSelect`→`DNativeSelect` first, then claim `DSelect`); `@multiple` (chips + array
   value) follows in P1 on the **same** component — built on the engine +
   internal parts (`DFilterInput` combobox, `<ul role="listbox">`,
   `<li role="option">`), wired to `a11y.announce`, using `DAsyncContent`'s `:loading`
   (`DSkeleton`) / `:empty` / `:error` blocks. Prove
   **both data strategies** (client-only sync `@options`, no skeleton; server-backed
   `@load`, skeleton + empty + error + retry) **and both interaction modes**
   (simple/static with `focus`-mode nav — the native-`<select>` replacement;
   searchable with hardened `active`-mode nav).
   Fresh integration + **a11y acceptance tests** (keyboard incl. spaces, arrows,
   Enter, Escape, Tab-doesn't-select; axe-core roles/names/wiring; no `role=alert`).
0g. **Migrate `DIconGridPicker`** announcements to the `a11y` service (removes its
   inline `aria-live` region) — validates the pattern.

## Roadmap — the whole effort (higher-level program)

Each phase is one or more approval cycles, individually shippable and reversible. The
end state is core + bundled plugins migrated off select-kit and banned from using it;
**select-kit itself is never deleted** (deprecated only, for third parties). Phase 0
(above) is the foundation. Sizes (S/M/L/XL) are relative effort, not calendar.

**Phase 1 — Complete & consolidate the core family** (M→L)
- **Typeahead-default rework** (API refinement › Decision 1): invert the trigger so
  the `typeahead` variant (input-as-trigger) is the default, built on `DMenu` with a
  non-button trigger component. Focus stays in the host input on desktop and moves to
  the query input inside `DMenu`'s modal on mobile; keep the Phase-0
  button+filter-in-panel as the `@variant="button"` case; `static` stays. Auto-highlight
  the first match. Default rows/selections use `@labelField`; custom `:item` and
  `:selection` blocks remain independent overrides.
- Add `@multiple` to `DSelect` (array value + chips) and rewrite the on-`main`
  `DMultiSelect` as a thin `@multiple` alias on the engine (fix the `ul/li` validity
  bug; keep its 3 consumers + test suite green); chip UX (keyboard remove + focus
  move), `@maximum`/`@minimum`; create-on-the-fly; `DLoadMore` pagination +
  loading-state granularity.
- **Large-list windowing (Decision 5), from the start**: internal render chunk (client
  default; server page size auto-detected from the first response); reveal via the
  `DLoadMore` sentinel up to a hard `MAX_RENDERED` cap, then stop + "filter to narrow"
  message; `aria-setsize`/`aria-posinset`. Ship with the 5k-sync performance gate. Not
  deferrable — it guards every client-source picker.
- **Chrome args** (API refinement): `@clearable`, `@caretIcon`, `@icon`, `@disabled`/
  `@readonly`, `@onShow`/`@onClose`, `@placement`/`@offset`, `@focusWrap`, `@openOn`,
  and an `:empty` block override.
- **Group/section-aware item model** (Decision 2): flat engine list + `role="group"`
  rendering + `@groupBy`; UI exercised later by the category family.
- Re-home `DIconGridPicker` on the engine (grid variant).
- Exit: generic single + multi cover every data strategy × all three variants, each
  with a11y acceptance tests (desktop + on-device mobile SR check for typeahead); the
  ad-hoc components are consolidated.

**Phase 2 — Extension API GA + tooling + first high-traffic migrations** (L)
- Finalize the `select-content`/`select-on-change` transformers + the
  `modifySelectKit` bridge (all six fidelity requirements); register new deprecation
  ids and wire `discourse-deprecation-collector`.
- Build the codemod harness (`ember-template-recast` + jscodeshift), handling both
  import specifiers and the runtime arg-alias table.
- Migrate the highest-traffic pickers behind facades under their old tags
  (`combo-box`, `category-chooser`); migrate FormKit's `select` control + the ~12
  native consumers; deprecate `DNativeSelect`.
- Exit: extension API documented + GA; codemod runs clean on core; deprecation
  telemetry live.

**Phase 3 — Specialized pickers (breadth)** (XL)
- Category family (chooser / drop / selector / admin-dropdown); tag family
  (tag-chooser / mini-tag / tag-drop / tag-group / intersection + `tag-utils`); user
  family (user-chooser / email-group-user-chooser + `addUserSearchOption`); and the
  long tail (timezone, future-date, flair, form-template, group, list-setting,
  color-palette(s), period, homepage-style, font).
- `DTopicSelect` (topic picker) — the **acceptance case for selected-value
  resolution** (id→title, content-only trigger skeleton, `@selected` escape hatch);
  fold in the parked handoff design. `TopicChooser` is deprecated **not deleted**
  (out-of-repo consumers + the `type: topic` site-setting).
- Port `discourse-ai` off `modifySelectKit` to the transformer API — the real-world
  acceptance test for the extension model; reback FormKit `tag-chooser`.
- Exit: every select-kit picker has a new-family equivalent behind a facade; core
  call sites codemodded.

**Phase 4 — Bespoke dropdowns + test infrastructure** (L)
- `composer-actions` (its own registry — `registerComposerAction` /
  `addComposerToolbarPopupMenuOption`), the notifications-button family, and the
  remaining `dropdown-select-box` variants (categories-admin, bulk-select-bookmarks,
  user-notifications).
- Rewrite the test infra hard-keyed to `.select-kit-*`: the JS helper
  (`tests/helpers/select-kit-helper.js`, ~54 acceptance files) and the Ruby page
  object (`spec/system/page_objects/components/select_kit.rb`, ~67 specs) to the new
  BEM/roles; re-verify system specs.
- Exit: core + bundled plugins fully off select-kit; test infra migrated.

**Phase 5 — Ban from core/bundled + finalize deprecation** (L)
- Port the ~19 bundled plugins that subclass select-kit bases off them (the last
  in-repo consumers).
- Add the **ban lint rule** (forbid `select-kit/*` imports + old tags in core `app/`,
  `admin/`, bundled `plugins/`) so new code can't reintroduce it.
- Publish the codemod + a migration guide for third-party plugins/themes (optional
  adoption; deprecation warnings + telemetry nudge them).
- **No deletion**: select-kit, its SCSS, `compat-modules`, the `modifySelectKit`
  bridge, and `DNativeSelect` remain (deprecated) for out-of-repo consumers.
- Exit: core + bundled fully migrated and banned from select-kit; select-kit stays,
  deprecated, for third parties.

**Cross-cutting (every phase)**: the a11y acceptance gate (automated + manual SR
matrix) and `discourse-visual-review`; coordination with Joffrey (select-kit author)
and the editor branch on the `dRovingFocus`/`DSkeleton` rebase.

## Open decisions (for the user / RFC readers)

- **Searchable mobile keyboard model**: RESOLVED (API refinement › Decision 3) —
  real-focus fallback inside DModal now, adopt d-sheets when it lands. Remaining: the
  on-device SR validation and the d-sheets adoption timing (coordinate with
  jaffeux/renato).
- **`composer-actions`**: RESOLVED — excluded; it's an action menu, already being
  replaced by its own `composer-actions-new` upcoming change on DMenu. Just ensure it
  is off select-kit before the final ban.
- **`DSelect` name**: RESOLVED — rename the native `<select>` wrapper →
  `DNativeSelect` (deprecated shim), give `DSelect` to the combobox (Martin agreed,
  dev #187302).
- **Trigger default**: RESOLVED — `typeahead` (API refinement › Decision 1).

## Risks & verification

- **Riskiest**: `dRovingFocus` hardening is unproven infra with no users; the
  `modifySelectKit` bridge fidelity (AI suggester is the acceptance test). Mitigate
  by proving both against fresh tests in Phase 0 before any migration.
- **Typeahead-default rework is the biggest Phase-1 risk** (per the adversarial
  review): it needs a purpose-built display-value-vs-edit-value input, explicit
  open/Escape/click wiring on `DInlineFloat`, a desktop/mobile two-DOM split, and a
  host-DOM bridge anchor — materially more than "invert the trigger." Prototype the
  input + focus/Escape model first and prove it before the multi-typeahead and preset
  work.
- **Latent Phase-0 equality bug**: the engine's strict-`===` value compare mishandles
  string-vs-number ids (`castInteger` case) — fix the equality contract in Phase 1 (or
  a Phase-0 follow-up) before any real picker binds a string id.
- **Verification**:
  - Phase 0 unit/integration: `bin/qunit` on the new component + engine + modifier
    tests; the a11y acceptance suite (keyboard + axe-core) must pass.
  - **Manual SR matrix before each phase ships**: NVDA + JAWS (Firefox/Chrome),
    VoiceOver (Safari desktop + **iOS**), TalkBack (**Android**) — each completing
    the four historically-broken flows (pick a category, add/remove a PM recipient,
    change topic tracking, create a tag).
  - `discourse-visual-review` across light/dark themes **and an RTL locale** at
    implementation time (caret/clear/chip/icon mirroring, placement).
  - **Thorough edge-case + performance suite** (the state model is the spec): exhaustive
    tests over the Decision-1b matrix (single/multi × typeahead/button/static ×
    selection-surface states × list-surface states); resolution fallbacks (404 /
    restricted / batch-omitted → a clearable `__unresolved` chip/label, never hidden);
    batch `@resolveValues` (one request, cached ids skipped); normalization with a
    non-`id` `@valueField` + synthetic-row keys; IME composition; multi `@value` dedup;
    chip-remove keeps focus + keeps the popover open; `reload()` shows a busy state
    despite retain; re-filter-from-empty shows busy; immutable-`@value` contract.
    **Performance gate: a 5k-item synchronous source renders only one render chunk on
    open** (assert DOM node count ≤ `MAX_RENDERED`, no hang) and stays responsive;
    reveal widens the window (sync) / pages (server) up to `MAX_RENDERED`, then shows
    the "filter to narrow" message; `aria-setsize`/`aria-posinset` reflect the true total.
  - `bin/lint --fix` on all changes; run the full suite green before merge
    (select-kit is on the production hot path).
