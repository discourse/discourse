# DSelect

A headless selection engine (`select-engine.ts`) plus one presentational component
(`d-select.gts`) that together replace the legacy select family. The engine owns state,
filtering, paging, value resolution, and the normalized render descriptors; the component
renders a WAI-ARIA combobox/listbox around a virtualized option list and forwards keyboard,
pointer, and overlay behavior. Consumers stay controlled: the parent owns `@value` and applies
what `@onChange` reports.

See the arg reference in `d-select.gts` (`Args` block) and the option reference in
`select-engine.ts` (`SelectEngineOptions`).

## Architecture

Both public modules are facades over focused collaborators in `-internals/`, organized by
kind. Consumers and tests never import from `-internals/`; the public API surface lives
entirely on `d-select.gts` and `select-engine.ts`.

- `-internals/engine/` — the headless layer behind `SelectEngine`, which stays the single
  stable identity (the legacy bridge and plugin hooks key on the engine instance):
  `select-sources.ts` (reactive state + local/paged sources), `select-options.ts` (live
  option readers with cross-option defaults), `list-composer.ts` (the ordered `buildItems`
  compiler and descriptor stamping), `selection-actions.ts` (selection operations, limits,
  and change-emission ordering), `value-resolver.ts` (value→item resolution and its caches).
- `-internals/coordinators/` — non-rendering component-side classes constructed once by
  `DSelect` and configured downward with thunks (never holding a component reference):
  `variant-presenter.ts` (variant/ARIA policy), `select-announcer.ts` (screen-reader
  announcement arbitration), `windowed-list-coordinator.ts` (windowing, pinning, and jump
  navigation), `interaction-coordinator.ts` (open/close, focus, and pointer session),
  `load-feedback.ts` (loading timers and skeleton sizing).
- `-internals/parts/` — the rendering subcomponents: trigger pieces (`trigger-frame`,
  `combobox-query-input`, `multi-chips`, `single-trigger-display`, `selection-label`) and
  the list (`select-listbox`, `select-item`). Parts receive the stable helper objects
  (`@engine`, `@presenter`, …) plus per-slot inputs; they add no wrapper DOM.
- `-internals/modifiers/` — element-attached behavior (`keep-above-keyboard.ts`, the iOS
  keyboard-occlusion correction).
- `-internals/modify-select-kit-bridge.ts` — the deprecated legacy compatibility bridge,
  slated for removal.

### Why the panel is portaled

The overlay is a `DMenu`, so on desktop float-kit teleports the panel into a portal outlet near
the document root rather than rendering it beside the trigger. That is deliberate and worth not
undoing: the portal is what lets the panel escape the `overflow` clipping and stacking context of
whatever contains the field, and a combobox has to work inside modals, the composer, the sidebar,
admin tables and chat. The component this replaces rendered its list inline and paid for it —
`position: fixed` by default on desktop, per-call-site strategy overrides, a `transform`
containing-block hack on one table container, and a recurring tail of "dropdown is cut off" fixes.

Rendering near the trigger (float-kit's `portalOutletElement`) was evaluated and rejected. It
would make the tab order correct for free, since the panel would be adjacent in document order,
but it re-acquires exactly that clipping tax. The cost is paid instead by `@inlineTabOrder`, which
makes the portaled panel take part in the tab sequence as if it were inline: Tab leads into the
panel's own controls and, off the end of them, continues from the trigger.

Two things to know when testing this area. float-kit renders floats **in place** under tests
(`DFloatPortal`, `@inline ?? isTesting()`), so a component test sees no portal unless it forces
one with `@inline={{false}}` plus an outlet — which is worth doing, since `tab()` dispatches a
cancelable keydown and so does exercise the real handling. What no component test can reach is a
browser adopting a scroll container as a tab stop: such an element reports `tabIndex === -1` and
matches no focusable selector, so `tab()` skips it whether or not it was suppressed. That one
assertion needs a real browser.

## Custom row content

Six named blocks control what the component renders: `:item`, `:selection`, `:groupHeader`,
`:empty`, `:footer` and `:error`.

**Supply a block only when an argument cannot express the content.** `@labelField` picks the
field to display, `@selectedIcon` marks the chosen row, `@icon` puts a glyph in the trigger, and
`@noResultsLabel` rewords the empty state. A block that reproduces one of those is not neutral:
it costs behaviour (see `:selection` below) and it costs the reader a reason to look.

### What each block replaces

All six land **inside** markup the component keeps, so you supply content, not structure — the
option's `role`, its selected and disabled state, its ARIA position, the group header's label id,
the empty state's `role="status"` and the error state's `role="alert"` are all still handled for
you.

`:error` is yielded `reload` alongside the error, so a block that wants its own recovery control
can render one; the component's retry is shown only when no block is supplied.

### Blocks that interact

Two behaviours only appear once blocks are used together, and both are easy to get wrong:

- **`:footer` outlives the list.** It is a sibling of the async content rather than part of it,
  so it renders in every panel state — while loading, when populated, when empty, and when the
  source has failed. Gate its contents on the yielded `total`/`loadedCount` rather than assuming
  there are rows, or a footer will read "12 results" underneath "Nothing matches".
- **A `:groupHeader` does not replace the option description.** Each option is
  `aria-describedby` a dedicated label span containing the group's label; arbitrary custom
  markup, counts, and hints remain visible in the header without being repeated for every row.

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
- Groups via `@groupBy` (a field name or `(item) => key`). The engine segments the filtered
  options and renders a structural boundary before each segment, and the boundary's presentation
  is label-driven: where `@groupLabel` yields text the boundary is a non-selectable header
  (custom markup via the `:groupHeader` block); where it yields nullish — or when `@groupLabel`
  is omitted entirely — the boundary is an unlabeled splitter, a purely visual rule that is
  suppressed at the head of the list. Grouping runs after filtering on every render, so
  boundaries are always recomputed: an empty group draws nothing, and a query keeps exactly the
  splitters that still separate two surviving groups. Client (`@items`) sources only.
  Headers are `role="presentation"` rows in the windowed list. Each option in a *labeled* group
  references the id-bearing label span in its header through `aria-describedby`
  (splitter-bounded options carry no group description — an unlabeled boundary has nothing to
  announce). The window extension pins a group's header while any of its rows are mounted, so
  descriptions resolve for every published window and the description DOM stays bounded by the
  window size by construction, even under near-unique `@groupBy`. The label span contains only
  the group's label text and is hidden when a custom `:groupHeader` renders, keeping arbitrary
  block markup out of option descriptions. The engine still rejects a string `@groupBy` that
  names the value field outright.

  The previous mechanism resolved ID references on every rendered frame; header pins guarantee
  them for every published window. During the one-runloop transient after an items change (the
  same stale-window interval covered by the `{{#if descriptor}}` row guard), a regrouped option
  can briefly reference a header outside the stale mounted set. Assistive technology treats that
  unresolvable ID reference as no description for that runloop.
  `aria-posinset`/`aria-setsize` stay global across groups: per-group numbering carries no
  meaning without nested `role="group"` semantics, which a windowed flat list cannot preserve.
  (The APG-sanctioned structure nests a `role="group"` with `aria-labelledby` between the
  listbox and its options; our flat virtualizer can't window nested group containers, so the
  flat association is the sanctioned fallback — nested groups are a follow-up.)
  **Invariant:** all structural rows are engine-injected. The `__header`/`__divider` fields on
  `SelectItem` are engine plumbing with no public constructor — never supply them in `@items`,
  `@load`, or `@specialItems` (grouping discards upstream structural rows and derives its own
  structure); those inputs must be selectable options.

### Missing (scheduled)

- **Server-side grouping** — `@groupBy` covers client sources; a group that spans fetched pages
  is deferred (a paginating source ignores `@groupBy`, splitters included).
- **Nested `role="group"` grouping semantics** — the APG-sanctioned optgroup structure (a
  `role="group"` + `aria-labelledby` wrapping each group's options, kept even under virtualization,
  which is what a windowed listbox has to preserve for the structure to mean anything). Requires
  the windowing primitive to position nested group containers; the current flat list uses the
  `aria-describedby` fallback instead.
- **Group-exclusive (radio) selection** — a multi-select where picking an option evicts its
  group-mates from the value. Designed, not implemented: see
  `docs/select-kit-replacement/RADIO-GROUPS-DESIGN.md`.
- **Misc knobs** — hidden native form input; hidden-value exclusion; autofocus / open-on-render;
  a consumer keydown boundary hook; configurable render cap and filter icon.

### Deferred decisions

- **Engine visibility** — `SelectEngine` stays a public headless entry point for now. Whether
  to narrow the sanctioned surface (keep this module exporting only the types and item
  helpers, move the class behind `-internals/engine/`) is deferred until a second renderer
  with real requirements exists: an internal class can be promoted later with one deliberate
  re-export, while a public one cannot be demoted once external code imports it. Revisit in a
  follow-up before external consumers appear.
- **`DIconGridPicker` as the first headless consumer** — the most concrete candidate for a
  second engine renderer: it currently re-implements filtering and result-count announcements
  by hand and shares the roving-focus and announcement infrastructure already, while its grid
  rendering stays its own concern. A spike porting it onto the engine would answer the
  visibility question above with a second real consumer instead of a hypothesis.

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
