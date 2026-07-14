# Phase 1 — Complete & consolidate the core family

**Goal:** the generic single + multi component covers every data strategy × trigger
variant, and the ad-hoc components are consolidated onto the engine.

See RFC: *Decision 1 / 1b / 2 / 5*, *API refinement › Folded into Phase 1*.

## Tasks

- ◐ **Typeahead-default rework** (Decision 1) — DESKTOP done (committed `0082efb5af8`, then
  amended to revert an un-deep-planned mobile opener; lint/types + DSelect suite green). Invert
  the trigger so `typeahead` (input-as-trigger) is the default; keep focus in the input; keep the
  Phase-0 button+filter-in-panel as `@variant="button"`; `static` stays. Auto-highlight the first
  match. **⚠ OPEN AFFORDANCE UNRESOLVED (pending its own deep-plan):** desktop opens only via the
  query input (label/caret inert); **mobile has no opener** (trigger holds no input). See the
  `skip`-ped test + the `TODO(select-kit-typeahead-open-affordance)` in `d-select.gts`, and the
  next planning cycle. Deferred: visual/SR pixel review (needs a live consumer). Plan
  `~/.claude/plans/vivid-drifting-puffin.md`. **Scope: single-select only** (multi = a later
  item; Decision-1b data model = below). **Overlay = reuse `DMenu`** (not `DInlineFloat` — Fork A
  chosen: `DMenu` honors a non-button `@triggerComponent`, and blocks can't cross a service-
  rendered list; Fork B rejected). **Hybrid taming:** intercept Tab locally + one additive
  `DMenu` change (yield `expanded` in `componentArgs`).
  - ☑ Base: rebased `select-kit-rework` onto `floatkit-to-ts` (PR #41633) for real `DMenu`
    types — **this branch now stacks on #41633 and can't merge until it does**.
  - ☑ Dropped the `ComponentLike` `DMenu` cast; `DMenu` yields `expanded` in `componentArgs`.
  - ☑ `@variant` (`typeahead`|`button`|`static`) replaces `@searchable`; derived getters +
    template branch; `focusListboxIfSimple` re-gated on `isStatic`.
  - ☑ `combobox-query-input.gts` (arity-agnostic query input: Tab `stopPropagation`, open on
    type/click/ArrowDown, Escape, IME composition gating, combobox ARIA).
  - ☑ Composite typeahead trigger (non-button `div` host; presentation sibling hidden while
    typing; query reset on `@onClose`; pointer-blur guard for action rows). Caret is a decorative
    icon (an interactive caret opener was reverted — see the open-affordance decision).
  - ☑ `autoActivateFirst` on `dRovingFocus` + `itemsKey={{items}}` for re-seed on async land.
  - ☑ SCSS (`--typeahead` box) · `pnpm lint:types` + `bin/lint` green.
  - ☑ Tests green (rendered-DOM integration: typing, keyboard, focus/ARIA, Escape/blur, action-row
    keep-open). The mobile arm + the open affordance are a `skip`-ped pending-design marker.
  - ☐ Open affordance decision (next cycle) — desktop click target + mobile opener + surface
    (DModal vs d-sheet); coordinate with RFC Decision 1/1b/3 and button/static/multi.
  - ☐ Visual/SR pixel review (implementation-time; blocked on a live consumer to screenshot).
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
