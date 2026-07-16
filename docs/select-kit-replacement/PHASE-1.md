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
  - ☐ **6b — chips arrow-roving** (deferred): wire `dRovingFocus tabStop=false
    orientation="horizontal"` on the chips group; ArrowLeft-at-caret-0 enters the chips, arrows
    move between, `onExit` returns to the input, Backspace/Delete on a focused chip removes it,
    input becomes the sole tab stop. (Known interim limitation: while the menu is open, Tab from
    a chip is forwarded into the listbox by DMenu; chip-to-chip Tab works only while closed.)
  - ☐ **RTL** (deferred): `dRovingFocus` has no direction handling — ArrowLeft/Right are
    hard-wired backward/forward. Add RTL entry (+ its one other consumer + tests) as its own item.
  - ☐ **Mobile M5** (deferred): closed trigger → real `<button aria-haspopup="dialog">` with
    inert chips; composite moves into the modal; the B1a/B1b/B2/B4 fixes.
  - ☐ Still to do (unchanged from before): `@maximum`/`@minimum`; pipe-paste bulk-add;
    clear-all (`@clearable`); rewrite on-`main` `DMultiSelect` as a thin `@multiple` alias.
  - ☐ Styleguide `@variant="button"`+`@multiple` and 6+-chip wrap examples; RFC line-123 vs
    238-242 mobile contradiction.
- ☐ **Large-list windowing** (Decision 5): internal render chunk (client) / server
  page-size auto-detected; hard `MAX_RENDERED` cap; `DLoadMore` reveal → "filter to
  narrow" at the cap; `aria-setsize`/`aria-posinset`. 5k-sync performance gate.
- ☐ **Chrome args**: `@clearable`, `@caretIcon` (open/closed pair), `@icon`, `@disabled`/
  `@readonly`, `@onShow`/`@onClose`, `@placement`/`@offset`, `@focusWrap`, `@openOn`,
  `@minChars`/`@debounceMs`, `:empty` block override, create-on-the-fly (`validateCreate`).
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
