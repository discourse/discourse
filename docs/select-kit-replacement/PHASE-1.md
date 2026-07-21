# Phase 1 — Complete & consolidate the core family

**Goal:** the generic single + multi component covers every data strategy × trigger
variant, and the ad-hoc components are consolidated onto the engine.

See RFC: *Decision 1 / 1b / 2 / 5*, *API refinement › Folded into Phase 1*.

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
    input-holds-only-query composite trigger; group flag UI (Decision 2).
  - ☐ Runtime `@multiple` toggling is **not supported**: the engine reads `multiple` once in
    its constructor, and `isTypeahead` hard-couples arity to variant. Decide whether a
    select may flip arity at runtime (and what happens to a held array when it flips to
    single) before any consumer relies on it.
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
  - ☐ Still to do (unchanged from before): `@maximum`/`@minimum`; pipe-paste bulk-add;
    clear-all (`@clearable`); rewrite on-`main` `DMultiSelect` as a thin `@multiple` alias.
  - ☐ Styleguide `@variant="button"`+`@multiple` and 6+-chip wrap examples; RFC line-123 vs
    238-242 mobile contradiction.
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
  - Add a `title` to each chip's remove button in addition to its accessible name.
  - Give disabled options a visually distinct default treatment, potentially reduced opacity,
    while preserving sufficient text and icon contrast.
- ☐ **Large-list reveal** (Decision 5): internal render chunk (client) / server
  page-size auto-detected; hard `MAX_RENDERED` cap; `DLoadMore` reveal → "filter to
  narrow" at the cap; `aria-setsize`/`aria-posinset`. 5k-sync performance gate.
  - ☑ Engine: `reveal` cursor, client range-slice and server page accumulator behind one
    `loadItems`, `canRevealMore`/`atCapWithMore`/`total`/`serverPending` gating, window reset
    on filter and reload.
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
  - ☐ **Placeholder placement.** Placeholders append below the last row, so they sit outside
    the viewport exactly when they matter: arrowing to the last option, scrolling to the
    bottom, or re-querying above stale rows. The listbox viewport fits 9 rows (320px against a
    38.4px row). A sticky bottom indicator is position-independent and would supersede the
    appended rows for reveals.
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
  - ☐ **`serverCompletedKey` write ordering on abort** (pre-existing). `#settleServerPage` sets it
    from `finally` on the abort path, and the generation counter is bumped only by `#resetWindow`,
    which the reveal path never calls. Two settles racing in one generation can leave the key on
    the older load, pinning `serverPending` true and `canRevealMore` false.
  - ☐ **Dedup key collisions across heterogeneous sources.** `#valueKey` is `String(value)` with no
    type namespace, so a user `id: 5` and a group `id: 5` collide and the second is dropped. This
    is also why a derived total describes the *navigable* set rather than the source's true count.
  - ☐ **`atCapWithMore` phrasing under truncation.** "Keep typing to narrow the results" is sound
    for a client cap; for a server-truncated set, typing may not help.
  - ☐ **`itemsKey` is conditional** (`d-select.gts`): non-typeahead variants key roving-focus
    reconciliation on the filter, so appended server pages never re-run `modify()`. Latent; the
    first run always sees real rows because the loading block is a separate list without the
    modifier.
  - ☐ **`selectKit.triggerSearch()` missing from the compat bridge.** The facade exposes only
    `value`/`filter`/`isLoading`/`close`/`select`/`set`, but at least one plugin calls
    `triggerSearch()`. It will throw once `mini-tag-chooser` moves to `DSelect`.
  - ☐ **Flaky: "resets the window when the query changes"** (`d_select_bounded_reveal_spec.rb`,
    client path, pre-existing). Observed failing once with 100 options where it asserts 50, then
    passing 3/3 isolated and 2/2 paired. After a filter reset the sentinel can already be within
    the observer's 200px root margin, so a client reveal — which needs no network — fires before
    the assertion runs. Waiting for a stable count rather than an immediate one would mask a real
    regression just as well, so the fix is probably to assert the reset synchronously (the window
    is one chunk at the moment the filter changes) rather than after the DOM settles.
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
  - ☐ **Selection outside the render window.** Still unreachable: a client selection past
    `MAX_RENDERED`, or a server selection in no fetched page. Close the client half when DSelect
    adopts `DVirtualList` (`scrollToIndex` handles any index); a selection at 50–199 is reachable
    by scrolling today, so no prefix-window stopgap was built. The server half is not solvable by
    rendering at all — it needs a locate-by-value contract from the source.
- ☑ **`DVirtualList` folded into this branch** (Decision 5 reversed on the record in the RFC).
  The windowing primitive, its bridge modifier, the library wall over `@tanstack/virtual-core`
  (pinned `3.17.5`), its SCSS, both test suites and a 10k-row styleguide demo now live here, so
  the two engines can be shaped against each other. Nothing is wired to `DSelect` yet.
  - ☐ **Wire DSelect to the primitive.** `@items` = the accumulated array, `@role="listbox"`,
    `@itemRole="option"`. Collides with `#describeList`'s own `posInSet`/`setSize` stamping —
    the primitive's row wrapper owns those once wired, and only a position-aware `@itemRole`
    stamps them, so the ownership boundary needs settling rather than assuming. `MAX_RENDERED`
    stops being necessary at that point.
  - ☐ **Roving focus over a moving window** — the blocker. `dRovingFocus` re-queries
    `querySelectorAll("[role=option]")` and assumes every navigable option is mounted, which is
    false once the window moves. An await-based shape was already rejected upstream (six
    verified defects) in favour of flag-and-reconcile at `#reconcileActive` — the same seam the
    selected-option restoration uses. Do not rediscover that.
  - ☐ **Edge-triggered fetching.** The primitive ships no load-more affordance, so the
    `DLoadMore` sentinel is replaced by comparing the visible range against the row count.
    `onVisibleRangeChange` fires on any state change, not only range changes, so it needs
    dedup and a per-edge latch with mount suppression.
  - ☐ **Primitive defects carried over, none blocking:** the API handle pins the items array on
    teardown, fractional/negative `@overscan` throws, the render-all fallback still measures
    every row, `onVisibleRangeChange` over-fires, and symbol-keyed items are held strongly.
  - ☐ **Engine path unification** (analysis done, not implemented). `this.#load` is branched on
    at eight sites, each a parallel implementation of accumulate / window / count / exhaustion —
    against the RFC's async-first intent, where the client case is "the same loader, not a
    separate path". Two standalone bugs fell out: a server source refetches a value already in
    its accumulator because the resolve ladder's known-rows rung is client-only, and `reveal`
    sits inside the load key so a reveal reads as a full re-identification of the query.
  - ☐ **`Home`/`End`.** Optional per APG, and reserved for the text caret in an editable
    combobox, so they suit the static variant only. `End` under a bounded window would land on
    the last rendered row rather than the last of the set; settle with the item above.
  - ☐ **Status-message contrast.** `--primary-medium` measures 3.15:1 on light (AA needs
    4.5:1); shared by the empty, keep-typing, narrow and error messages, so it is a
    token-level decision.
  - ☐ 5k-sync performance gate; visual pass (Foundation + Horizon, light + dark).
  - ☐ Deferred to its own cycle: the `dRovingFocus` keyboard-boundary hook. v1 reveals
    through the prefetch sentinel for both pointer and keyboard.
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
- ☐ **Group/section-aware model** (Decision 2): flat engine list + `role="group"` +
  `@groupBy`; UI exercised later by the category family.
- ☑ **Value-equality contract**: the engine matches ids by a normalized string key
  (`#valueKey`), so a bound `"5"` selects item id `5` (both directions) and the resolved
  cache no longer misses on a string/number mismatch. Always-on, no `castInteger` opt-in.
- ☐ Re-home `DIconGridPicker` on the engine (grid variant).

## Test gate

Run before calling any item done. `--filter` is a **literal substring** here (regex and
`/slashes/` only work under `--standalone`), so the family is covered by one shared substring
rather than a union:

```bash
bin/qunit --filter "ui-kit"   # 460 tests, ~35s — SelectEngine, the bridge, every DSelect
                              # module, dRovingFocus, plus ui-kit collateral
bin/qunit --filter "A11y"     # 17 — the shared live-region service
bin/qunit --module "Integration | Component | DIconGridPicker"   # 32 — the other a11y consumer
```

The last two matter because the a11y service's own tests are named
`Integration | Component | A11y | LiveRegions`, not `ui-kit` — a `ui-kit`-only run misses them.

Known pre-existing failure, unrelated to this phase: `Integration | ui-kit | DDateTimeInput:
allows mutations through actions` (verified red on a pristine HEAD).

`pnpm lint:types` does **not** check `.js` tests — `tsconfig-base.json` sets `allowJs` with no
`checkJs`. A test asserting a typed engine API should be `.ts` so the checker guards it; runtime
`-test.ts` is supported (#41636).

## Exit criteria

- Single + multi cover every data strategy × all three variants, each with a11y
  acceptance tests (desktop + on-device mobile SR check for typeahead).
- The 5k-sync performance gate passes.
- `DMultiSelect`/`DIconGridPicker` consolidated onto the engine; their suites green.
