# DSelect

A headless selection engine (`select-engine.ts`) plus one presentational component
(`d-select.gts`) that together replace the legacy select family. The engine owns state,
filtering, paging, value resolution, and the normalized render descriptors; the component
renders a WAI-ARIA combobox/listbox around a virtualized option list and forwards keyboard,
pointer, and overlay behavior. Consumers stay controlled: the parent owns `@value` and applies
what `@onChange` reports.

See the arg reference in `d-select.gts` (`Args` block) and the option reference in
`select-engine.ts` (`SelectEngineOptions`).

## Custom row content

Six named blocks control what the component renders: `:item`, `:selection`, `:groupHeader`,
`:empty`, `:footer` and `:error`.

**Supply a block only when an argument cannot express the content.** `@labelField` picks the
field to display, `@selectedIcon` marks the chosen row, `@icon` puts a glyph in the trigger, and
`@noResultsLabel` rewords the empty state. A block that reproduces one of those is not neutral:
it costs behaviour (see `:selection` below) and it costs the reader a reason to look.

### What each block replaces

All six land **inside** markup the component keeps, so you supply content, not structure — the
option's `role`, its selected and disabled state, its ARIA position, the group header's id, the
empty state's `role="status"` and the error state's `role="alert"` are all still handled for you.

`:error` is yielded `reload` alongside the error, so a block that wants its own recovery control
can render one; the component's retry is shown only when no block is supplied.

### Blocks that interact

Two behaviours only appear once blocks are used together, and both are easy to get wrong:

- **`:footer` outlives the list.** It is a sibling of the async content rather than part of it,
  so it renders in every panel state — while loading, when populated, when empty, and when the
  source has failed. Gate its contents on the yielded `total`/`loadedCount` rather than assuming
  there are rows, or a footer will read "12 results" underneath "Nothing matches".
- **A `:groupHeader`'s text is read after every option beneath it.** Each option is
  `aria-describedby` its header, so a count or hint added to the header is announced on every
  row in the group. Keep headers to a short name.

### Accessibility rules for block content

- Icons rendered through the icon helper are `aria-hidden` by default. Do not give one an
  `aria-label` in a row whose text already names it.
- Avatars and other decorative images need an empty `alt`, or the row's name is doubled.
- In a multi-select, a chip's accessible name is built from what `:selection` renders (the label
  span is hidden and pulled back in by the remove button). An icon-only or image-only chip is
  announced as a bare remove button.
- Never render a trailing bare number; it is announced as part of the option's name ("performance
  871"). Use a phrase, or hide the visual figure and supply one.
- `role="option"` forbids interactive descendants, so no buttons or links inside `:item`.
- **Naming the control:** use `@label`, or `aria-labelledby` pointing at your own caption. A
  wrapping `<label>` also works: the trigger renders an unrendered input as its first labelable
  descendant, so the browser resolves the label to that sink instead of to whichever button
  happens to come first (a chip's remove control, or the clear control) — without it, clicking a
  field's caption would silently drop a selection. The sink then forwards the activation on as a
  focus, so a caption puts the caret in the field without opening the panel. It is also why
  adding a control to the trigger needs no click guard of its own.
- `:selection` is the only block whose mere presence changes behaviour. On a desktop typeahead it
  moves the label out of the input into a sibling element until the field is focused; the input's
  value is empty at rest, and the control advertises the selection through `aria-describedby`
  instead.

Worked examples of every point above live on the styleguide's select page, under Row content.

## Capability parity & gaps

This tracks DSelect against the behaviors it must eventually cover. It is intentionally honest
about what is not built yet, so a consumer can tell "use it" from "not ready." Describe entries
by mechanism.

### Covered

- Single and multiple selection, with chips and per-chip removal (`@multiple`).
- A first-class "none" row on single-select (`@noneLabel`): a selectable list row that clears the
  value to `null` and reads as selected while nothing is chosen. Always present while browsing, and
  filtered out under an active query so a non-matching search still reaches the empty state.
- Client (`@items`) and server (`@load`) sources; true pagination with tail reveal and a render
  cap; `@filterBy` field or predicate; `@minChars` gate; `@debounce`.
- Create-on-the-fly (`@allowCreate` + `@createItem`); prepended special rows (`@specialItems`).
- Async value resolution for held-but-unfetched ids (`@resolveValue` / `@resolveValues`) with a
  named unresolved fallback (`@createUnresolvedItem`). A resolver may answer synchronously, so a
  consumer already holding the item just returns it; `@load` answers queries and is never asked
  "what is this id", so an async source that can mount holding a value needs a resolver.
- `@valueItems`: already-resolved item(s) for the ids in `@value`, read reactively. It selects
  nothing itself — entries are looked up BY `@value` — but unlike a resolver it may arrive after
  mount, so a consumer loading them itself refreshes every selection surface when they land.
- Multi-select value-type coercion: each emitted id is normalized to its source item's native type
  (so a URL-typed `"5"` and a freshly-picked `3` never emit as a mixed `["5", 3]`); an unresolved id
  passes through unchanged, and `@value` is never mutated (the engine only emits via `@onChange`).
- Per-item `disabled`; per-item action rows (`onSelect`, which run instead of selecting and keep
  the overlay open).
- Selected-row indicator (`@selectedIcon`): shown always in multi-select (default check) and, in
  single-select, when the arg is set.
- Trigger variants (`@variant`: typeahead / button / static); a leading `@icon`; a label-less
  icon-only trigger on the button/static variants (`@iconOnly`, which requires `@label` for the
  accessible name — drive `@icon` from `@value` for a selection-reactive glyph); caret swap
  (`@caretIcon`) and caret suppression (`@showCaret={{false}}`); `@clearable`; `@disabled` /
  `@readonly`; overlay placement (`@placement` / `@offset`); `@onShow` / `@onClose`.
- Custom row and selection markup (`:item` / `:selection` blocks; on the typeahead variant the
  `:selection` block is the resting/closed display — once the menu opens the built-in input shows
  the editable label text, so it is not a live-while-editing surface); empty state
  (`@noResultsLabel` / `:empty`); loading skeleton (`@skeletonCount`); a muted source-error state
  with an optional retry (`@retryable`) and an `:error` consumer block.
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

### Missing (scheduled)

- **Server-side grouping** — `@groupBy` covers client sources; a group that spans fetched pages
  is deferred (a paginating source ignores `@groupBy`).
- **Nested `role="group"` grouping semantics** — the APG-sanctioned optgroup structure (a
  `role="group"` + `aria-labelledby` wrapping each group's options, kept even under virtualization,
  which is what a windowed listbox has to preserve for the structure to mean anything). Requires
  the windowing primitive to position nested group containers; the current flat list uses the
  `aria-describedby` fallback instead.
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
