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
    the resolved label until the first edit, selects it on focus, and restores it on close. Rich
    custom selection markup remains a sibling and is hidden while editing. The caret is
    decorative; clicking anywhere in the trigger opens the control.
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
- ☐ **Trigger & list state model** (Decision 1b): input-holds-only-query composite
  trigger; the two async surfaces; skeleton taxonomy; batch `@resolveValues`; `__unresolved`
  fallback items; item **normalization** (`{ key, value, item, flags }`, no `id` assumption).
- ☐ **`@multiple` + chips** (shadcn `ComboboxChips` model): chips-with-inline-input,
  keep-selected-with-checkmark (supersede Phase-0 remove-on-select + its test), backspace
  removal, clear-all; `@maximum`/`@minimum`; pipe-paste bulk-add; rewrite on-`main`
  `DMultiSelect` as a thin `@multiple` alias (keep its consumers + tests green).
- ☐ **Large-list windowing** (Decision 5): internal render chunk (client) / server
  page-size auto-detected; hard `MAX_RENDERED` cap; `DLoadMore` reveal → "filter to
  narrow" at the cap; `aria-setsize`/`aria-posinset`. 5k-sync performance gate.
- ☐ **Chrome args**: `@clearable`, `@caretIcon` (open/closed pair), `@icon`, `@disabled`/
  `@readonly`, `@onShow`/`@onClose`, `@placement`/`@offset`, `@focusWrap`, `@openOn`,
  `@minChars`/`@debounceMs`, `:empty` block override, create-on-the-fly (`validateCreate`).
- ☐ **Group/section-aware model** (Decision 2): flat engine list + `role="group"` +
  `@groupBy`; UI exercised later by the category family.
- ☐ **`castInteger`/value-equality contract**: fix the strict-`===` engine compare
  (string-id vs number-id) before any real picker binds a string id.
- ☐ Re-home `DIconGridPicker` on the engine (grid variant).

## Exit criteria

- Single + multi cover every data strategy × all three variants, each with a11y
  acceptance tests (desktop + on-device mobile SR check for typeahead).
- The 5k-sync performance gate passes.
- `DMultiSelect`/`DIconGridPicker` consolidated onto the engine; their suites green.
