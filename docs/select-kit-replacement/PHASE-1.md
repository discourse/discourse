# Phase 1 — Complete & consolidate the core family

**Goal:** the generic single + multi component covers every data strategy × trigger
variant, and the ad-hoc components are consolidated onto the engine.

See RFC: *Decision 1 / 1b / 2 / 5*, *API refinement › Folded into Phase 1*.

> **Last reconciled against the code at `ad80441c0c7`** (2026-07-24). The previous reconciliation
> was `74ab32e3b68`, twenty commits earlier, and this file had drifted badly — it still claimed
> `DVirtualList` was unwired and listed shipped work as open. Claims below marked ☑/◐ in that
> catch-up were re-verified against the source, not taken from commit messages. **Re-stamp this
> line whenever you close an item**, so the next reader can size the drift.

## Tasks

- ◐ **Typeahead-default rework** (Decision 1) — the single-select desktop and mobile baseline
  is implemented. `typeahead` (input-as-trigger) is the default; the Phase-0
  button+filter-in-panel remains `@variant="button"`; `static` remains unsearchable. The whole
  trigger opens the control: desktop keeps focus in its input, while mobile opens `DMenu`'s
  modal and focuses the query input there. The first match is auto-highlighted. **Scope:
  single-select only** (multi's typeahead interaction is a later item; the current Phase-0
  multi trigger remains). **Overlay = reuse `DMenu`** (not `DInlineFloat` — Fork A chosen:
  `DMenu` honors a non-button `@triggerComponent`, and blocks can't cross a service-rendered
  list; Fork B rejected). **Hybrid taming:** intercept Tab locally + one additive `DMenu`
  change (yield `expanded` in `componentArgs`).
  - ☑ Base: rebased `select-kit-rework` onto `floatkit-to-ts` (PR #41633) for real `DMenu`
    types — **this branch now stacks on #41633 and can't merge until it does**.
  - ☑ Dropped the `ComponentLike` `DMenu` cast; `DMenu` yields `expanded` in `componentArgs`.
  - ☑ `@variant` (`typeahead`|`button`|`static`) replaces `@searchable`; derived getters +
    template branch; `focusListboxIfSimple` re-gated on `isStatic`.
  - ☑ `combobox-query-input.gts` (arity-agnostic query input: Tab `stopPropagation`, open on
    type/click/ArrowDown, Escape, IME composition gating, combobox ARIA).
  - ☑ Composite typeahead trigger (non-button `div` host; query reset on `@onClose`;
    pointer-blur guard for action rows). Without a custom `:selection` block, the input displays
    the resolved label until the first edit and restores it on close. A keyboard focus (Tab-in)
    selects the label for overtype; a pointer press keeps the caret where the click landed, and
    the label is never re-selected after a selection. Rich custom selection markup remains a
    sibling and is hidden while editing. The caret is decorative; clicking anywhere in the
    trigger opens the control.
  - ☑ `:item` and `:selection` are optional. All variants, multi chips, and mobile fall back
    to `@labelField` (default `name`), while either block can still override its corresponding
    presentation independently. Resolved labels are held in a reactive engine cache so an
    async label can populate an already-mounted input without remounting it.
  - ☑ `autoActivateFirst` on `dRovingFocus` + `itemsKey={{items}}` for re-seed on async land.
  - ☑ Form-control styling is shared across variants: input sizing, themed background,
    border, text/placeholder colors, focus treatment, and inline inset. The dropdown content
    and panel both fill the matched trigger width.
  - ☑ `pnpm lint:types` + `bin/lint` green.
  - ☑ Tests green (rendered-DOM integration: typing, keyboard, focus/ARIA, Escape/blur, action-row
    keep-open, optional-block fallbacks, stable async resolution, cross-variant sizing/colors,
    matched dropdown width, and the mobile arm).
  - ☑ Open affordance decision — use the whole `DMenu` trigger as the click target; use its
    `DModal` surface on mobile and keep the input in the host trigger on desktop.
  - ☑ Permanent Styleguide harness for variants, async states, retry, empty results, and multi.
  - ☑ Theme screenshot coverage for Foundation/Horizon × light/dark × desktop/mobile;
    visual review confirms empty-control and dropdown-width parity. Manual on-device SR review
    remains part of the phase exit criteria.
  - ☐ **Backlog (skipped review items)** — add tests when next editing these paths:
    `handleTriggerBlur` keep-open branch; auto-highlight skipping a disabled first item;
    `preventPointerBlur` static no-op; `legacy.getElement` host-DOM invariant (incl. mobile).
    Convention nit: unkeyed `{{#each}}` at `d-roving-focus-test.gjs:395` (pre-existing) → key it.
- ◐ **Trigger & list state model** (Decision 1b):
  - ☑ Item **normalization** — `buildItems` returns `{ key, value, item, flags }` descriptors
    (final render step; raw items unchanged upstream). The listbox keys on `descriptor.key`
    (no `id` assumption; `key="id"` removed) and the option reads state from `flags`
    (`selected`/`disabled`/`__create`); `group`/`__unresolved` flags reserved.
  - ☑ Batch `@resolveValues`, one chokepoint for both arities — single is a batch of one,
    narrowed back to a bare item. Precedence: `@resolveValues` (either arity) → per-id
    `@resolveValue` (single: one call; multi: documented fan-out) → `__unresolved` fallback.
    `@resolveValue` stays as single-select sugar.
  - ☑ `__unresolved` fallback — resolution never rejects/blanks a held value, whether the
    resolver rejects **or throws synchronously**; each unresolvable id becomes
    `{ [valueField]: id, __unresolved: true }`, rendered as the value plus a warning icon +
    "unavailable" tooltip (muted) + `.sr-only` state text (the icon is `aria-hidden` and the
    tooltip sits on an unfocusable child, so the state has to be carried in text), or
    "%{value} (unavailable)" in the plain typeahead input. `:selection`-block consumers
    branch on `item.__unresolved`.
  - ☑ `@createUnresolvedItem` — `(value) => item` names the fallback (e.g. `Topic #123`)
    on every surface, the plain input included, where a block can't reach. The engine owns
    the `__unresolved` marker regardless of what the builder returns.
  - ☑ Resolve caching policy — successes are cached; a failure caches its fallback so the
    trigger can tell "failed" from "still resolving", and `reload()` evicts fallbacks so
    they retry. The fallback ranks LAST in the sync ladder (escape hatch → resolved cache →
    client list → fallback), so an item landing later supersedes it. **A cached fallback
    must stay a cache hit**: the resolve writes this tracked cache, so a read that missed
    would re-resolve, re-write, invalidate the render that read it and never settle. The
    original "no tracked-cache write during resolve" note was preventing exactly that loop.
  - ☐ Custom `:unresolved` / `:selectionLoading` / `:loadingItem` blocks; skeleton taxonomy;
    input-holds-only-query composite trigger. (Group flag UI landed with `@groupBy` — see
    the Decision 2 item below.)
  - ☑ **Runtime input reactivity** (`f6ed1eb9649`). The engine captured every input but
    `@value` in its constructor, so `@items`, `@selected`, `@multiple`, `@minChars` and
    `@allowCreate` were inert after mount — a foundation defect for the component meant to
    back the migration. All five now read through thunk-backed private getters that resolve
    live and re-apply their defaults, wired from DSelect's args like the existing `getValue`
    thunk; `closeOnSelect` re-derives `!multiple` with them. `loadContext` reads the effective
    local items synchronously so a client-source change restarts the list even on the
    debounced path, where the async function runs outside the cached computation and cannot
    autotrack the source itself. `#localItems` normalizes through `makeArray`; supplying both
    `@items` and `@load` warns once, with `@load` winning. `isTypeahead` is now purely
    variant-derived (no arity coupling), so a runtime arity flip is mechanically supported.
  - ☐ **Arity-flip semantics** remain undefined: what becomes of a held array when `@multiple`
    goes true → false. Settle before any consumer relies on flipping.
- ◐ **`@multiple` + chips** (shadcn `ComboboxChips` model):
  - ☑ **The flip (desktop)** — `@multiple` now routes through the typeahead machinery:
    `isTypeahead` drops its `!multiple` guard; the trigger renders chips inline with the query
    input (chips hoisted above the variant branch, input a sibling of the chips `DAsyncContent`
    so it doesn't remount on resolve); selecting adds a chip, keeps the menu open, resets the
    query only on an add, and keeps the input focused; keep-selected-with-checkmark +
    `aria-multiselectable`; Backspace on the empty input removes the last chip (both desktop and
    modal inputs, composition-guarded); add/remove announced politely with the self-inflicted
    refilter count suppressed (`#suppressNextCount`, leak-guarded); `removeItem` restores input
    focus. `.--multiple` SCSS (left-align, no double inset). New broad oracle
    `d-select-multi-flip-test.gjs` + updated `DSelect (multi typeahead)` module, all green.
  - ☑ **6b — chips arrow-roving** — `dRovingFocus selectionMode=focus tabStop=false
    orientation="horizontal" itemSelector=".d-combobox__chip-remove"` on the chips group, applied
    via a desktop-gated conditional curried modifier `{{(if this.isDesktopTypeahead (modifier …))}}`
    so mobile is byte-identical. The chips are a native `<ul>`/`<li>` list (`aria-label` +
    `display: contents` so the `<li>`s flow inline with the input, which is a sibling — an
    `<input>` can't live in a `<ul>`), giving real "Selected items, list, N items" semantics
    without an ARIA-role guess (validated against Higley's user-tested pens + GitHub Primer). The
    remove **button** is the roving item; its accessible name leads with the item then the removal
    hint ("Orange, Press Backspace or Delete to remove" — Primer style) via a reordered
    `aria-labelledby`. ArrowLeft-at-caret-0 (composition-guarded, `hasValue`) enters the chip
    nearest the input via `focusLast()`; arrows move; `onExit(forward)` returns to the input; the
    far edge stays. Backspace/Delete remove + move focus to the **previous** chip
    (`focusIndex(max(0, index-1))`, `nextRunloop`, Primer) with an input fallback; Enter/Space use
    the button's native activation (→ `removeItem` → input). **Escape** is owned by float-kit's
    document-capture listener (closes the menu; focus stays on the chip); **ArrowDown/ArrowUp**
    from a chip jump to the input and open the list (the reopen gesture, keeps the
    `aria-activedescendant` model coherent). Static `tabindex=-1` on each remove button (desktop)
    makes the input the sole tab stop with no re-seed dependency. `dRovingFocus`
    `focusFirst/Last/Index` now return `boolean` (did-land, for the fallback). sr-only
    `aria-describedby` hint on the input ("Press Left arrow to reach selected items."). Chip
    hover states + a whole-chip `:focus-visible` ring (keyed off `:has(.d-combobox__chip-remove
    :focus-visible)`, button outline suppressed). Oracle: `d-select-multi-flip-test.gjs` + a system spec (native Enter +
    real Tab order) driving the styleguide's multi example, at
    `plugins/styleguide/spec/system/d_select_multi_chip_roving_spec.rb` **temporarily** (system
    tests need a real page and the styleguide is the only multi surface today — move to core
    `spec/system` once a real core consumer renders `DSelect @multiple`), plus the reusable
    core-owned page object `PageObjects::Components::UiKit::DSelect`. (Known accepted interim:
    while the menu is open, Tab from a chip is forwarded into the listbox by DMenu.)
  - ☐ **RTL** (deferred): `dRovingFocus` has no direction handling — ArrowLeft/Right are
    hard-wired backward/forward. Add RTL entry (+ its one other consumer + tests) as its own item.
  - ☐ **Mobile M5** (deferred): closed trigger → real `<button aria-haspopup="dialog">` with
    inert chips; composite moves into the modal; the B1a/B1b/B2/B4 fixes.
  - ☑ **`@maximum`/`@minimum`** (`1204ec45981`) — the cap lands at the engine's single
    `select()` chokepoint, so pointer, keyboard, create-on-the-fly and the compat bridge are
    all covered by one guard. Unselected options render disabled at the cap, while pre-seeded
    over-cap values stay displayed and removable rather than being trimmed. `@minimum` is
    advisory. The limit message renders in a dedicated top-of-panel zone, and `dRovingFocus`
    now clears a highlight left on a row that became disabled at runtime.
  - ☐ Still to do: pipe-paste bulk-add; multi clear-all; rewrite on-`main` `DMultiSelect`
    (still `app/ui-kit/d-multi-select.gjs`) as a thin `@multiple` alias.
  - ☐ Styleguide `@variant="button"`+`@multiple` and 6+-chip wrap examples; RFC line-123 vs
    238-242 mobile contradiction.
- ◐ **Sandbox screen-reader and design feedback** (dev topic #188731) — tracked separately in
  [`SANDBOX-A11Y-REMEDIATION.md`](SANDBOX-A11Y-REMEDIATION.md), which carries the item table,
  the "express states, announce events" rule that governs every `DSelect` announcement, the
  per-announcement inventory, and the diagnoses that were published and then disproved. Read it
  before adding or moving any announcement.

- ☐ **Post-showcase UX follow-ups** — address after the concurrent implementation work lands:
  - Selecting an already-selected item does not close the dropdown. Define and implement
    consistent re-selection behavior across variants.
  - Created items need a stable, discoverable position in long or paginated lists. Prefer
    staging them at the top, but do not make the create action the default while ordinary
    matches remain. Research select-kit's current ordering and activation behavior before
    settling the interaction.
  - Decide whether removing a newly created item's chip should also remove that staged item
    from the open list. The current preference is yes for the lifetime of the open list;
    validate that against established multi-select UX before implementing it.
  - Decide whether a multi-select typeahead should retain an input placeholder when it already
    has selected items instead of presenting an empty input.
  - Add a `title` to each chip's remove button in addition to its accessible name. (Still
    absent — no `title=` on `.d-combobox__chip-remove`.)
  - Give disabled options a visually distinct default treatment, potentially reduced opacity,
    while preserving sufficient text and icon contrast. **Partly there and in tension with the
    contrast item:** `d-combobox.scss` now styles `[aria-disabled="true"]` as
    `color: var(--primary-medium); cursor: not-allowed` — but that is the same 3.15:1 token
    flagged under status-message contrast, so "distinct" is currently bought with contrast that
    already fails AA. Settle both together.
- ☐ **Large-list reveal** (Decision 5): server page-size auto-detected; hard `MAX_RENDERED`
  cap (**server-only** since `199ac768089`); reveal → "filter to narrow" at the cap;
  `aria-setsize`/`aria-posinset`. 5k-sync performance gate.
  - ☑ Engine: `reveal` cursor, client range-slice and server page accumulator behind one
    `loadItems`, `canRevealMore`/`atCapWithMore`/`total`/`serverPending` gating, window reset
    on filter and reload. **Superseded in part**: the client half of this was retired once
    `DVirtualList` took over windowing (see the engine-unification item below).
  - ☑ Template: listbox `aria-busy`, the `<li role="presentation">` sentinel rooted at the
    listbox (the observer now takes an element, not just a selector), the narrow hint,
    per-option `aria-setsize`/`aria-posinset` from true totals, and count / loading-more
    announcements through the `a11y` service. Styleguide large-list example plus a system
    spec that drives a real container scroll — the one gate QUnit cannot cover, since
    IntersectionObserver does not fire there.
  - ☑ Loading feedback: placeholders appear only after a delay, so a fast source never
    flashes one; a re-query replaces the list, a reveal appends. Paginated styleguide
    examples (reported total, cursor) cover the busy state, the loading announcements, and the
    unknown-set-size encoding.
  - ◐ **Placeholder placement.** Largely defused by windowing, not fixed: placeholders are
    still appended (`#frontierSkeletons`, `[...items, ...skeletons]`), but the frontier is now
    where the viewport *is* when a reveal fires, since reveal is edge-triggered by
    `@onReachEnd` rather than by a sentinel below the fold. The remaining case is the
    re-query: a new query resets the windowed scroll to the top while the placeholders sit at
    the end of the stale list. A sticky bottom indicator is still the position-independent
    answer if that case proves to matter.
  - ☑ **Separate `hasMore` from `total`, and invert the default.** `SelectLoadResponse` gained
    `hasMore`, and **silence now means complete**: only `hasMore: true` or a `total` above the
    rows returned buys another fetch. A source that cannot say whether more exists is not fit for
    pagination, so the engine takes it at its word instead of probing — which previously cost
    every such source two wasted round-trips, each long enough to paint a loading placeholder.
    Because silence is an assertion of completeness, the accumulated count becomes a truthful
    `aria-setsize`; `-1` now means only "mid-paging under `hasMore`". Exhaustion reached *without*
    such an assertion — the barren-page brake, a reported ceiling — must never size the set, since
    the brake is the "source ignores `offset`" detector. Truncation at the cap is exact (a
    discarded non-duplicate row, not merely a full list), so it both withdraws the derived size
    and drives the narrow hint. `hasMore` is per-response; `total` stays sticky and outranks the
    navigable row count.
  - ◐ **`serverCompletedKey` write ordering on abort** (pre-existing). The `finally` block now
    guards the write on `generation === this.#serverGeneration` and documents the call
    deliberately: completion covers rejection *and* abort, because skipping the abort path left
    the key behind the live one forever, pinning `aria-busy` on and `canRevealMore` false. The
    accepted cost is that a same-key retry reads as settled while genuinely in flight — a brief
    missing busy signal rather than a dead control. Re-check whether two settles racing inside
    one generation can still strand the key on the older load.
  - ☐ **Dedup key collisions across heterogeneous sources.** Still open: `#valueKey` is
    `String(value)` with no type namespace, so a user `id: 5` and a group `id: 5` collide and
    the second is dropped. This is also why a derived total describes the *navigable* set
    rather than the source's true count.
  - ☐ **`atCapWithMore` phrasing under truncation.** Now strictly a server concern — the client
    cap is gone, so every `atCapWithMore` is a server-truncated set, and "Keep typing to narrow
    the results" (`d_select.filter_to_narrow`) is exactly the case where typing may not help.
  - ☐ **`itemsKey` is conditional** (`d-select.gts`): non-typeahead variants key roving-focus
    reconciliation on the filter, so appended server pages never re-run `modify()`. Latent; the
    first run always sees real rows because the loading block is a separate list without the
    modifier.
  - ☐ **`selectKit.triggerSearch()` missing from the compat bridge.** The facade exposes only
    `value`/`filter`/`isLoading`/`close`/`select`/`set`, but at least one plugin calls
    `triggerSearch()`. It will throw once `mini-tag-chooser` moves to `DSelect`.
  - ☑ **Flaky: "resets the window when the query changes"** — dissolved rather than fixed. The
    flake was a client reveal firing off the observer sentinel before the assertion ran; both
    the client render window and the sentinel are gone (`199ac768089`, `ab295dfffbc`), and
    `d_select_bounded_reveal_spec.rb` was rewritten to assert the *loaded frontier* grows on
    scroll (`c369877b6d1`). Watch for a successor flake now that the assertion is scroll-driven.
  - ☑ **Selected option active on open.** `dRovingFocus` gained `autoActivateSelected`, giving
    active mode the `aria-selected` preference `#seedTabStop` already had in focus mode, so a
    rendered selection is activated and scrolled to (restoring what select-kit's `_scrollToCurrent`
    did). It outranks `autoActivateFirst`, so `button` restores too; it is off while filtering
    (the first match is what Enter should take) and off for `multiple`, where activating a
    selected row would make Enter call `deselect` and silently drop a value. Re-picking the
    current value now closes without emitting a change — otherwise the restored cursor made Enter
    inert — which also fixed the pointer case where clicking the selected row did nothing.
    `#requestClose` is gated on the overlay actually being open, since `DMenuInstance.close`
    focuses the trigger by default and the compat bridge lets consumers call `select()` long
    after dismissing the overlay.
  - ◐ **Selection outside the render window.** **Client half closed** as predicted: DSelect
    adopted `DVirtualList`, the client cap is gone, and the listbox API's `scrollToIndex`
    reaches any index (`d-select.gts` `#listboxApi.scrollToIndex`, fed by `@pinnedIndices`).
    **Server half still open** and still not solvable by rendering — a selection sitting in no
    fetched page needs a locate-by-value contract from the source.
- ◐ **`DVirtualList` folded into this branch, and now wired** (Decision 5 reversed on the
  record in the RFC). The windowing primitive, its bridge modifier, the library wall over
  `@tanstack/virtual-core` (pinned `3.17.5`), its SCSS, both test suites and the styleguide
  demos live here, and `DSelect`'s option list renders through it.
  - ☑ **Primitive grown into the windowing surface** (`d2b38dcbbc6`, `faf7aebf36f`). Rows key
    on a stable `@key` field instead of object identity, so rebuilding item objects no longer
    orphans measured heights. Rendering is per-row absolute `translateY` with native
    `@as`/`@ownedRow` elements via `dElement`, so the semantic list tree and ARIA live on the
    inner container while the outer viewport scrolls. A symmetric edge API
    (`@onReachStart`/`@onReachEnd`, threshold + hysteresis, mount and initial-fill handling)
    replaced the over-firing `onVisibleRangeChange` for consumers, and
    `@initialIndex`/`@pinnedIndices` add flash-free deep-open and off-window pinning, the pinned
    row merged in index order so DOM and `aria-posinset` stay monotonic. The positioning
    modifier is one stable instance applied with args, so a re-render updates it in place
    rather than letting an old instance's teardown strip a reused row's styles. The
    spacer-vs-per-row spike concluded for per-row (only per-row composes with `@pinnedIndices`)
    and the spike components were deleted.
  - ☑ **Wire DSelect to the primitive** (`ab295dfffbc`). The listbox renders in owned-row mode,
    yielding `SelectItem` rows (plus frontier skeletons during a server reveal) as direct
    children of the inner listbox; the `DLoadMore` sentinel is gone, replaced by `@onReachEnd`.
    The roving highlight moved from the modifier's imperative class to tracked state
    (`SelectItem` `@active`, cleared on close) so it survives the windowed row re-render that
    the imperative toggle did not. The scroll viewport moved from the listbox to the outer
    `.d-virtual-list`. **Ownership boundary settled** the other way than assumed: `#describeList`
    keeps stamping `posInSet`/`setSize` from true engine totals rather than ceding them to the
    row wrapper — see the partial-load item below.
  - ☑ **Roving focus over a moving window** — the ex-blocker, closed in two steps.
    `6ff1de494f1` gave `dRovingFocus` absolute logical navigation: `Home`/`End`/`PageUp`/
    `PageDown` target logical rows rather than the mounted slice, bounded by a new
    `logicalCount`, with `onJump(target, direction)` handing an off-window target to the
    consumer; without `logicalCount` the behaviour is unchanged. `ea1a19bb4da` wired DSelect to
    it: a jump outside the mounted window scrolls the target in, then refocuses on the next
    runloop once the new window commits, with the active row pinned so `aria-activedescendant`
    never dangles. The row block is guarded against a transiently-absent descriptor (a
    shrinking item array whose published window briefly outruns it), and the mobile static
    list seeds its pin on initial focus. The earlier `focusLogicalIndex`/`onEdgeReach` seams
    (`0da85314449`) were the first cut. As predicted, no await-based shape was used.
  - ☑ **Edge-triggered fetching.** Delivered as the primitive's `@onReachEnd`/`@onReachStart`
    edge API (with threshold, hysteresis and mount suppression) rather than as consumer-side
    dedup over `onVisibleRangeChange`. DSelect consumes the edge callbacks and never reads
    `onVisibleRangeChange`.
  - ☑ **Contiguity after an item-set change** (`d6f372cba6a`). virtual-core caches its scroll
    offset and refreshes it only from the scroll element's events, so when `@items` shrinks and
    then grows — a select filtered to one match and widened again — the browser clamps
    `scrollTop` without firing an observed event and the window is computed from a stale,
    out-of-range offset. With `@pinnedIndices` set that painted the pinned row at the top and the
    window far below it, with a visible gap between. The modifier now re-reads the element's
    real `scrollTop` on an item-set update whenever it disagrees with the cached offset, and
    no-ops when they match.
  - ☑ **Element-cache sweep pinned** (`017610a72f8`). `dVirtualizer` calls
    `measureElement(null)` each flush to evict disconnected rows from the engine's
    ResizeObserver, which never fires on removal; without it the cache grows with every row
    scrolled past. That version-sensitive virtual-core contract now has a unit test.
  - ☑ **Modifier inert when virtualization is off** (`a649e0b6e3d`). The test toggle gated only
    the component's rendering, so a disabled modifier still built the engine and fired
    edge/range callbacks off a zero-height container. `modify()` now returns early and tears
    down any engine a prior enabled run built, and
    `disableVirtualization()`/`enableVirtualization()` are wired into the test harness
    alongside the load-more toggle so rendering tests mount every row.
  - ☑ **Engine path unification** (`199ac768089`, `fd1f63ffcf1`). The client render window
    (`#clientWindow`, the client reveal, the 50/200-row client chunk and cap) is gone — a
    client list renders in full and is windowed by `DVirtualList`. The five source-kind getters
    plus `#knownRows` collapsed behind a construction-time `#source` strategy
    (`LocalSource`/`PagedSource`), so no consumer branches on client-vs-paged; server
    pagination, its accumulator, cap and dedup moved into `PagedSource` unchanged and
    `MAX_RENDERED` survives as the **server-only** cap. Both fallout bugs are fixed: the
    resolve ladder's known-rows rung now reads the source-appropriate buffer (`#knownRows`), so
    a server source no longer refetches a value already in its accumulator. Because the full
    filtered list drives the window, a new query resets the windowed scroll to the top, which
    the per-query engine window did implicitly before.
  - ☑ **`Home`/`End`** — settled with the item above rather than deferred. In active mode the
    Page keys always page the listbox, while `Home`/`End` stay with the caret for an editable
    controller and move to the ends for a non-editable one, so the editable-combobox caret
    reservation is honoured without giving up the static variant. `End` landing short of the
    true end is now an honest state, not a lie: see partial-load sizing below.
  - ☑ **Honest `aria-setsize` under partial load** (`6adae1aa620`). A server source that
    declares more rows than it has loaded cannot size its set, so its descriptors report
    `aria-setsize="-1"` — each row keeping its own position — until it completes. A client
    source and a complete server source keep their true, known size. `End` therefore lands on
    the last loaded row as "option N" rather than a misleading "option N of «declared total»".
  - ☐ **`itemsKey` is conditional** (`d-select.gts`, unchanged). Non-typeahead variants still
    key roving-focus reconciliation on the filter (`itemsKey=(if this.isTypeahead items
    this.rovingNonTypeaheadKey)`), so appended server pages never re-run `modify()`. Latent;
    the first run always sees real rows because the loading block is a separate list without
    the modifier.
  - ☐ **Primitive defects carried over, none blocking** (re-checked, still present): the API
    handle pins the items array on teardown, fractional/negative `@overscan` throws
    (`overscan ?? 5`, no validation), the render-all fallback still measures every row, and
    symbol-keyed items are held strongly. `onVisibleRangeChange` still over-fires but no
    longer has a consumer — decide whether to fix or drop it.
  - ☐ **Status-message contrast** (unchanged). `--primary-medium` measures 3.15:1 on light (AA
    needs 4.5:1); `d-combobox.scss` uses it for the empty, keep-typing, narrow and error
    messages among others, so it is a token-level decision.
  - ◐ 5k-sync performance gate still to run. Visual pass: the styleguide showcase was rewritten
    for the windowed list (`5f069e955ec` — the old copy still described the retired 50-row
    window, sentinel and hard cap) and gained a desktop screenshot marker that opens the large
    list and scrolls it deep, so the theme matrix now covers windowed rendering. Reading the
    resulting shots across Foundation/Horizon × light/dark is outstanding.
  - ☑ The `dRovingFocus` keyboard-boundary hook is no longer a deferred cycle: the prefetch
    sentinel is gone, and keyboard reveal now runs through `logicalCount` + `onJump` and the
    primitive's edge callbacks, the same path as pointer.
- ☑ **Chrome args** (commit `0f93bdf`): the trigger is unified onto a focusable `div` with
  per-variant WAI-ARIA roles (static select-only combobox, button disclosure, typeahead/multi
  input) and the leading-icon/clear/caret are extracted into one no-wrapper trigger frame. On
  it: `@icon`, `@caretIcon` (`string | {open, closed}`), `@clearable`, `@disabled`/`@readonly`
  (the locked gate covers every open+mutate path, including option activation itself so a
  control locked mid-close can't mutate), `@debounce`/`@minChars`, `@placement`/`@offset`,
  composed `@onShow`/`@onClose`, and a consumer `:empty` block. Supporting float-kit: a single
  `resolveRenderInModal` source, a reactive DMenu `@disabled` veto (closes an open menu),
  roving-focus scrolls the listbox not the page, and DAsyncContent assimilates sync sources.
  **Deferred:** `@openOn` (needs a float-kit `focus` trigger), `@focusWrap`, create-on-the-fly
  (`@validateCreate`).
- ☑ **Group/section-aware model** (Decision 2, `1204ec45981`, unified later in this phase):
  `@groupBy` segments a client source into sections; a boundary renders as a non-selectable
  header where `@groupLabel` yields text and as an unlabeled splitter otherwise, with each
  option associated to its group's label span via `aria-describedby`; the window extension pins
  the header while any row from that group is mounted.
  Still to be exercised by the category family; grouping a *server* source is untested.
- ☑ **Capability parity pass** — three commits of select-kit feature catch-up that predate any
  tracker line of their own:
  - `1204ec45981`: `@selectedIcon` (selected indicator in single-select), `@showCaret` to
    suppress the trigger caret, a `:footer` block rendering keyboard-reachable content pinned
    below the list and yielding live dropdown state, and a default source-error state that is
    now a muted recoverable message with an optional retry plus an `:error` override block.
  - `d5bea47065f`: `@noneLabel` gives a single-select a first-class none row — a selectable row
    (value `null`) that clears the selection and reads as selected while nothing is chosen,
    injected through the engine's special-row counting path so its ARIA position and keyboard
    index stay in lockstep, and hidden under an active query so a non-matching search still
    reaches the empty state. A multi-select now coerces each emitted id to its resolved source
    item's native type, so a URL-typed `"5"` and a freshly-picked `3` stop leaving as a mixed
    `["5", 3]`; unresolved ids pass through unchanged and `@value` is never mutated.
    `@iconOnly` renders a label-less trigger on the `button`/`static` single-select variants,
    requiring `@label` for the accessible name (debug assertion), and every overlay gained a
    tunable min-width floor (`--d-combobox-menu-min-width`) so a compact trigger's panel is
    never clipped.
  - `ad80441c0c7`: on the typeahead variant a `:selection` block is a **resting adornment**,
    not a lock. It previously rendered into a non-editable presentation span and pinned the
    query input empty, so the field could not be typed into. While the trigger input holds
    focus it now shows the plain selected label, selected for overtype like the block-free
    typeahead, reverting to the custom markup when focus leaves. A `didUpdate` selects the
    label as it appears so the first keystroke overtypes rather than appends. Clicking outside
    reverts too, via a document `pointerdown` listener that drops focus explicitly — the
    browser leaves the input focused when a press lands on a non-focusable element. Escape and
    selecting an option both keep focus and therefore keep the label. **Open question for the
    user:** whether selecting should instead snap straight back to the custom markup.
- ☑ **Value-equality contract**: the engine matches ids by a normalized string key
  (`#valueKey`), so a bound `"5"` selects item id `5` (both directions) and the resolved
  cache no longer misses on a string/number mismatch. Always-on, no `castInteger` opt-in.
- ☐ Re-home `DIconGridPicker` on the engine (grid variant).
- ☐ **Chase down the `d_select_cursor_source_spec` flake.** A full styleguide run failed it once
  on `expect(combobox.options.first[:"aria-setsize"]).to eq("1")` with `options.first` nil. It
  passed in isolation *and* on a re-run under the same seed (39916), so ordering is not the
  trigger and a plain retry proves nothing. Note the shape before theorising: the preceding
  `have_css(option_selector, count: 1, wait: 10)` had already *passed*, so the row existed and
  then was gone by the time `options` re-queried it. That is a check-then-fetch race against a
  virtualized list that re-renders once the filter settles, not a selector-scope problem — the
  page object's `in_panel` already scopes every option query to this instance's overlay. Fix it
  by reading the row once (`find` inside the waiting assertion, or a `have_css` carrying the
  `aria-setsize` value) instead of waiting on one query and reading from a second. The failing
  run also logged a 500 and a 404, so rule the environment in or out before assuming the spec
  is the whole story. Loop the suite afterwards to confirm the flake is gone rather than merely
  absent. Do not defer this into the Phase 4 test-infra rewrite: it is a live gate spec now,
  and a gate that fails once in a while is a gate nobody trusts.

## Test gate

Run before calling any item done. **Correction to the previous note:** `--filter` is a
case-insensitive substring *or* a slash-wrapped regex (`/foo/i`), and the regex form is **not**
restricted to `--standalone` — `bin/qunit --help` documents both forms for either mode. One
shared substring still covers the family more cheaply than an alternation:

```bash
bin/qunit --filter "ui-kit"   # 845 tests — SelectEngine, the bridge, every DSelect module,
                              # dRovingFocus, DVirtualList + the virtualizer, ui-kit collateral
bin/qunit --filter "A11y"     # 20 — the shared live-region service
bin/qunit --module "Integration | Component | DIconGridPicker"   # 32 — the other a11y consumer
```

The last two matter because the a11y service's own tests are named
`Integration | Component | A11y | LiveRegions`, not `ui-kit` — a `ui-kit`-only run misses them.

QUnit is not the whole gate. Scroll, real focus order and native activation only exist in a
browser, so six system specs now ride along — all in the **styleguide plugin**, which is still
the only surface rendering `DSelect` (they move to core `spec/system` once a real consumer does):

```bash
bin/rspec plugins/styleguide/spec/system/d_select_bounded_reveal_spec.rb \
          plugins/styleguide/spec/system/d_select_cursor_source_spec.rb \
          plugins/styleguide/spec/system/d_select_multi_chip_roving_spec.rb \
          plugins/styleguide/spec/system/d_select_no_probe_spec.rb \
          plugins/styleguide/spec/system/d_select_showcases_spec.rb \
          plugins/styleguide/spec/system/d_select_windowed_nav_spec.rb
```

They share the core-owned page object `PageObjects::Components::UiKit::DSelect` plus the
styleguide's `SelectShowcases`. Since windowing landed, the page object no longer counts mounted
options to measure loading — it reads the loaded frontier from the highest reachable
`data-index`, and it has helpers for the active/focused option and the windowed reveal
(`c369877b6d1`).

The previously-noted pre-existing failure (`Integration | ui-kit | DDateTimeInput: allows
mutations through actions`) is **gone** — it ran and passed in the run above, so it was fixed
upstream. No gate test is reliably red, but `d_select_cursor_source_spec` is a known
intermittent (see the task above): it has failed a full-suite run and then passed the same
seed, so treat a lone failure there as unproven rather than as either a regression or noise,
and re-run the seed before drawing a conclusion.

`pnpm lint:types` does **not** check `.js` tests — `tsconfig-base.json` sets `allowJs` with no
`checkJs`. A test asserting a typed engine API should be `.ts` so the checker guards it; runtime
`-test.ts` is supported (#41636).

## Exit criteria

- Single + multi cover every data strategy × all three variants, each with a11y
  acceptance tests (desktop + on-device mobile SR check for typeahead).
- The 5k-sync performance gate passes.
- `DMultiSelect`/`DIconGridPicker` consolidated onto the engine; their suites green.
