# DSelect

A headless selection engine (`select-engine.ts`) plus one presentational component
(`d-select.gts`) that together replace the legacy select family. The engine owns state,
filtering, paging, value resolution, and the normalized render descriptors; the component
renders a WAI-ARIA combobox/listbox around a virtualized option list and forwards keyboard,
pointer, and overlay behavior. Consumers stay controlled: the parent owns `@value` and applies
what `@onChange` reports.

See the arg reference in `d-select.gts` (`Args` block) and the option reference in
`select-engine.ts` (`SelectEngineOptions`).

## Capability parity & gaps

This tracks DSelect against the behaviors it must eventually cover. It is intentionally honest
about what is not built yet, so a consumer can tell "use it" from "not ready." Describe entries
by mechanism.

### Covered

- Single and multiple selection, with chips and per-chip removal (`@multiple`).
- Client (`@items`) and server (`@load`) sources; true pagination with tail reveal and a render
  cap; `@filterBy` field or predicate; `@minChars` gate; `@debounce`.
- Create-on-the-fly (`@allowCreate` + `@createItem`); prepended special rows (`@specialItems`).
- Async value resolution for held-but-unfetched ids (`@resolveValue` / `@resolveValues`) with a
  named unresolved fallback (`@createUnresolvedItem`); the `@selected` sync escape hatch.
- Per-item `disabled`; per-item action rows (`onSelect`, which run instead of selecting and keep
  the overlay open).
- Selected-row indicator (`@selectedIcon`): shown always in multi-select (default check) and, in
  single-select, when the arg is set.
- Trigger variants (`@variant`: typeahead / button / static); `@icon`; caret swap (`@caretIcon`)
  and caret suppression (`@showCaret={{false}}`); `@clearable`; `@disabled` / `@readonly`; overlay
  placement (`@placement` / `@offset`); `@onShow` / `@onClose`.
- Custom row and selection markup (`:item` / `:selection` blocks); empty state (`@noResultsLabel`
  / `:empty`); loading skeleton (`@skeletonCount`); a muted source-error state with an optional
  retry (`@retryable`) and an `:error` consumer block.
- A pinned `:footer` block below the option list (labels, links, action buttons), keyboard-reachable
  and yielding live state `{filter, value, hasValue, total, loadedCount, maximum, minimum, atMaximum,
  belowMinimum, remaining, close}` so its content can react (e.g. a "plus N more" from
  `total - loadedCount`).
- Selection limits (`@maximum` / `@minimum`, multi-select). `@maximum` is a hard cap enforced at the
  engine's single `select()` chokepoint (so pointer, keyboard, create-on-the-fly, and the compat
  bridge are all covered) and reinforced by disabling every unselected option at the cap; a value
  seeded over the cap is displayed and removable, never trimmed. `@minimum` is advisory (message +
  state only, never blocks removal — the consuming form owns submit-time enforcement). A built-in
  limit message renders in a dedicated top zone of the panel (never stacking with the footer or an
  error body), and the limit state is exposed on the engine and yielded to `:footer`.
- Value transformers and behavior hooks keyed on `@identifiers` (`select-content` /
  `select-on-change`), plus richer screen-reader announcements than the legacy family.
- Group / section headers via `@groupBy` (a field name or `(item) => key`) with `@groupLabel`
  for the header text and a `:groupHeader` block for custom markup. The engine segments the
  filtered options and injects a non-selectable header before each group; an empty group
  produces no header. Client (`@items`) sources only. Headers are `role="presentation"`, and
  each option references its group via `aria-describedby`, so a screen reader announces the group
  name. (The APG-sanctioned structure nests a `role="group"` with `aria-labelledby` between the
  listbox and its options; our flat virtualizer can't window nested group containers, so the
  `aria-describedby` association is the sanctioned flat fallback — nested groups are a follow-up.)
  **Invariant:** structural rows are engine-injected — never put `__header`/`__divider` markers in
  `@items`, `@load`, or `@specialItems`; those inputs must be selectable options.

### Partial

- **None / clear row** — no first-class "none" row; approximated by `@placeholder` +
  `@clearable` + `@specialItems`.
- **Trigger display** — no icon-only trigger mode (`@showCaret` hides the caret, but the label
  can't yet be dropped) and no multi-icon leading slot.
- **Value coercion** — ids match by string form (`"5"` selects `5`), but the emitted value type
  is never coerced back.

### Missing (scheduled)

- **Server-side grouping** — `@groupBy` covers client sources; a group that spans fetched pages
  is deferred (a paginating source ignores `@groupBy`).
- **Nested `role="group"` grouping semantics** — the APG-sanctioned optgroup structure (a
  `role="group"` + `aria-labelledby` wrapping each group's options, kept even under virtualization
  the way react-aria does). Requires the windowing primitive to position nested group containers;
  the current flat list uses the `aria-describedby` fallback instead.
- **Dividers** — the structural divider row-kind exists in the descriptor seam (excluded from
  selection, navigation, and ARIA position), but `@groupBy` does not emit dividers and no public
  arg produces one yet; it is groundwork for the panel-region work below.
- **Misc knobs** — hidden native form input; hidden-value exclusion; autofocus / open-on-render;
  a consumer keydown boundary hook; configurable render cap and filter icon.

### Deferred / out of scope

- **Grid / multi-column layout** — a two-dimensional picker is a separate primitive, not a linear
  select.
- **Server-side grouping** — `@groupBy` covers client sources first; a group that spans fetched
  pages is deferred.
- **Mobile multi-select chip keyboard** — chip keyboard navigation is desktop-only; the mobile
  trigger has no inline input to enter the chips from.
- **Full component overrides** — swapping the trigger, filter, or per-row component wholesale is
  intentionally not offered; customization is the headless engine plus the `:item` / `:selection`
  blocks.
- **Legacy compatibility bridge** — `-internals/modify-select-kit-bridge.ts` is a migration aid,
  deprecated, and slated for removal, not a kept API.
