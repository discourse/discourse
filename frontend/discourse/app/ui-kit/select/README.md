# DSelect

A headless selection engine (`select-engine.ts`) plus two public components
(`d-select.gts` and `d-select-list.gts`) that together replace the legacy select family. The engine owns state,
filtering, paging, value resolution, and the normalized render descriptors; the component
renders a WAI-ARIA combobox/listbox around a virtualized option list and forwards keyboard,
pointer, and overlay behavior. Consumers stay controlled: the parent owns `@value` and applies
what `@onChange` reports.

See the arg reference in `d-select.gts` (`Args` block) and the option reference in
`select-engine.ts` (`SelectEngineOptions`).

Direct `SelectEngine` consumers must have `getValue` read tracked state when the value can
change, or return a fixed value. Replacing an array must update tracked state; editing it in
place requires a tracked collection such as `trackedArray`. Untracked changes are unsupported.
The engine memoizes the normalized held value across reads and list rebuilds, and Glimmer
invalidates it when its tracked inputs change. `SelectHost` wires `getValue` to the component's
tracked `@value` argument. The public `value` remains an id or `null` in single mode and a
frozen, de-duplicated array in multi mode.

### Test and styling hooks

These attributes are a stable contract for tests and styling. Option rows expose
`data-value` as the descriptor value converted to a string and `data-name` as the configured
label. The none row has an empty value; a create row uses the item returned by `@createItem`
for its value and name. Resolved chips expose their held item's `data-value` and `data-name`;
loading skeleton chips carry neither attribute.

The `.d-select` root always exposes `data-value` and `data-name` as comma-separated held ids
and selection labels in held order, or empty strings when nothing is held. Unresolved ids
retain their values and use the engine's fallback selection labels. Both attributes follow
the selection reactively without starting additional async resolution.

The root also always exposes a unique `data-select-id` that stays stable for the instance's
life. Its `.d-select__panel` carries the same value whenever mounted, including loading,
empty, error, minimum-query-length and mobile modal states. No panel is mounted while closed.

The panel is portaled, so styles on the root never reach it. Its overlay, `.d-select__content`,
carries a `--kind-<kind>` modifier when the select has a `@kind`, which is how a recipe or theme
styles one kind's panel, for example `.d-select__content.--kind-select-tag-filter` to set
`--d-select-menu-min-width`.

Tests drive a select through these hooks with `dSelect()` (actions) and `assert.dSelect()`
(checks) from `discourse/tests/helpers/`, and with `PageObjects::Components::UiKit::DSelect.at`
in system specs.

## Creating items

`@allowCreate` and `@createItem` enable creation from the query. The create row always comes
after sticky, none and special rows, before the source rows and their group headers. With
ordinary source rows, typing a partial match and pressing Enter creates the typed text
(for example, "jav" creates "jav"), matching the legacy select behavior.

The create row, its `@allowCreate` check and its duplicate checks use the query whose rows
are on screen. While a new query is pending, retained rows keep the previous query's create
proposal, including for debounced local sources. The live `@minChars` gate still hides the
list below the minimum.

Creation is suppressed when a loaded row's label matches the typed text case-insensitively,
or when `valueKey(itemValue(createItem(filter)))` matches a loaded row's key. Comparing keys
normalizes numeric and string ids. The typed text matching a row's raw value alone does not
block creation; `@allowCreate` can impose additional rules.

`@createItem` should name the item by its value text, without a "Create" prefix. The engine
renders `d_select.create_item` ("Create “%{label}”") around that label. The `data-name` hook
remains the item label, and a consumer `:item` block overrides the row's content.

## Compact triggers

`@maxVisibleChips={{N}}` limits a multi-select trigger on every variant and device.
Zero shows the held count; a positive N shows the first N chips followed by `+K` for
those hidden. The badge is decorative (`aria-hidden`) and clicking it opens the panel
through the trigger. The controller's accessible name becomes “Label, K selected”,
including zero; desktop typeahead puts that name on its input, other variants on the root.

Button, static and mobile trigger chips are always display-only. Desktop typeahead
chips stay removable unless `@maxVisibleChips` is set. Display-only chip labels remain
exposed to assistive technology. Every display-only trigger references a visually hidden
list of **all** held labels in `aria-describedby`, merged with `@describedBy`, even when
locked. The list sits outside the named root so disabled fields still expose their labels.
The chips and that list share one resolution of the held values, and the resolver joins
requests already in flight, so the same ids are never fetched twice.

## The panel field

Wherever the list stays visible (a button select's popup, the mobile modal, and
`DSelectList`), the panel has a search field. Held chips sit inside it, before the caret,
where the rows alone cannot show every held item: in the mobile modal, which covers the
trigger; for an async source, whose loaded page may lack them; with `@hideSelected`; and
always in `DSelectList`, which has no trigger. Elsewhere, such as a local desktop popup, the
selected rows and the trigger's chips already show them, so the field holds only the input.
`@panelChips={{true}}` opts such a popup into field chips. While a panel lists the held
items, a button or static trigger shrinks to one line reading "N selected" instead of
repeating them. The field is a single Tab stop. Its input is a search field (`type="search"`, no role) that drives the
listbox through `aria-activedescendant`, with `aria-autocomplete="list"` and
`aria-controls` while a listbox is rendered. Only the desktop typeahead trigger, whose list
opens and closes, keeps `role="combobox"`.

From the input:

- Up/Down, PageUp/PageDown and Enter move through and pick results.
- Home/End and Left/Right move the caret and clear the active row, so screen readers read
  the text again. Up or Down brings the row back.
- Left at the start of the input enters the chips (Right in right-to-left pages).
- Backspace on an empty query removes the last held item, or clears a single value. A
  multi-select field without chips leaves the selection alone on both keys, so nothing is
  removed out of sight.
- Escape closes a popup or modal. In `DSelectList` it clears a non-empty query and
  otherwise leaves Escape to the containing panel.

From a chip:

- Left and Right move between chips; moving past the last one returns to the input.
- Backspace or Delete remove the chip. Focus moves to the previous chip, or the next one,
  before the chip goes, so it never falls to the page. Removing the only chip returns focus
  to the input.
- Enter, Space or a press remove the chip and return focus to the input.
- Tab and Shift+Tab leave the whole field.

Adds and removals are announced (“Added X”, “Removed X”). While a chip has focus, no
result row shows as active. Locked or read-only chips keep focus but carry
`aria-disabled="true"` and cannot be removed. Keyboard chip names lead with the label and
include the removal hint; touch names say “Remove X”.

Touch screen readers ignore `aria-activedescendant`. When a session starts on iOS or Android
and the latest interaction carried no key or pointer press (a screen reader's double-tap
or focus move), that session moves real focus through the results instead: the input
points at no row, no row is pre-activated, and a pick does not pull focus back to the
input. The shared `ui-kit/-internals/interaction-modality` tracker records that signal.

The input keeps a minimum width and wraps onto its own line rather than shrinking. The
field scrolls within `--d-select-field-max-height` (default `8em`) and keeps the focused
chip or the caret line in view. Remove targets are at least 24px, and 44px on touch and
in the modal. The whole panel has a height budget (`--d-select-panel-max-height`, default
`min(32em, 70dvh)`); the results take the remaining space and remeasure when the field
wraps. Clicking a label that wraps the field focuses the input, never a chip.

Two surfaces keep a separate selection strip instead:

- **The static variant** has no search. In the modal or with a server source it keeps a
  strip; a desktop static list with local `@items` shows held items as checked rows
  instead.
- **A capped desktop typeahead** (`@maxVisibleChips`) lists every held item in a strip
  in its panel. Left at the start of the input opens the panel and focuses the strip's
  last chip; Tab from the input enters the strip, and Up/Down or Shift+Tab return to the
  input. The strip scrolls within `--d-select-strip-max-height` (default `8em`).

Closing clears only a panel/modal input captured for that session; persistent desktop
controllers remain registered. Escape from the panel returns focus to the connected
desktop typeahead trigger input, or the focusable trigger root for other variants, never
a panel input.
Existing desktop trigger chips retain focus across Escape. Closing because focus left the
field preserves the outside control's focus.

## Loading inputs and keyboard activation

Keep `@load` stable for the component's lifetime. Pass its reactive inputs in a plain object
through `@loadContext`, for example `@loadContext={{hash categoryId=this.categoryId}}`.
The loader receives a shallow, frozen snapshot as `opts.context` alongside `opts.options`;
`spec.load` customizations receive that same snapshot as `context.loadContext`. Every page and
retry of one query uses the same snapshot. An array entry compares by its elements, so a call site
may derive an equal array on every render (`@exclude` rebuilt after each pick) without reloading;
an array changed in place still counts. Other values, including nested ones, compare by identity.

`@load(query, opts)` returns an item array or `{ items, total?, hasMore?, cursor? }`.
Paged sources receive the raw row `opts.offset`, a page-size `opts.limit` hint, and a 1-based
`opts.page` for an endpoint that pages by number. `opts.page` counts settled pages, barren ones
included; a failed or abandoned page is asked again under the same number.
The engine passes an opaque response `cursor` unchanged as the next request's `opts.cursor`.
Only a successful, current-query page advances it; a failed page keeps the previous cursor,
and a filter change or reload clears it, as it restarts `opts.page` at 1. A `spec.load` wrapper
must forward `(query, opts)` and preserve the response metadata, including `cursor`.

Server lists have no row ceiling by default. Set `@maxLoaded` to stop at that many unique
loaded rows and show the filter-to-narrow hint when results remain or rows were discarded.
Virtualization bounds mounted rows independently of the number loaded. A response with
`hasMore: false` ends paging; otherwise `hasMore: true` or a larger `total` permits another
page. Two consecutive pages that add no unique rows stop paging even if the source claims more.

The engine compares all own keys and their values with the current query's request snapshot,
including the key count. A new object with equal entries reuses the settled list. Changed
entries reload while open, or on the next open when closed. Open-list checks run after render
and recheck the session and live context before acting. Retained content keeps the context of
its displayed rows separately from the request being made.

A context change reloads the list: it resets the source, restarts at the first page, and
increments the reload nonce so an already-settled answer cannot be reused. It also resets result
announcement deduplication and the non-typeahead roving seed. It preserves pending `update()`
authority and unavailable held-value fallbacks. Explicit `control.reload()` performs the same
list reload and additionally evicts unavailable fallbacks so their resolution is retried;
successfully resolved held items stay cached.

While a server query or context reload is pending, keyboard activation is held, including the
debounce window and the skeleton before any row is mounted. Each Enter press politely announces
“Still loading…” and selects nothing; press Enter again after results arrive. Activation is not
queued. Revealing another page leaves activation available, and local sources are unaffected.
Below `@minChars`, the keep-typing hint takes precedence over the loading announcement.

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
- `-internals/coordinators/` — non-rendering component-side classes, constructed once and
  configured with thunks (never holding a component reference):
  `select-host.ts` (engine construction, selection, source context and helper ownership),
  `select-presenter-base.ts` (shared presentation and the options presenter contract),
  `variant-presenter.ts` (variant/ARIA policy), `select-announcer.ts` (screen-reader
  announcement arbitration), `windowed-list-coordinator.ts` (windowing, keeping rows mounted,
  sticky rows, and jump navigation), `interaction-coordinator.ts` (open/close, focus, and
  pointer session), `load-feedback.ts` (loading timers and skeleton sizing).
- `-internals/parts/` — the rendering subcomponents: trigger pieces (`trigger-frame`,
  `combobox-query-input`, `multi-chips`, `single-trigger-display`, `selection-label`),
  the list (`select-options`, `windowed-option-list`, `select-option-row`, `select-item`),
  the shared panel body (`select-panel`), and the selection strip kept by the static and
  capped variants (`selection-strip`). The options part owns the async shell
  and yields composed rows, their resolved content and configured per-list modifiers to its
  body. The windowed body and shared row part keep their elements and modifier order.
  Parts receive the stable helper objects (`@engine`, `@presenter`, …) plus per-slot inputs;
  they add no wrapper DOM.
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

Named blocks control what the component renders: `:item`, `:selection`, `:selectionLoading`,
`:unresolved`, `:groupHeader`, `:groupFooter`, `:skeletonItem`, `:empty`, `:listHeader`,
`:footer` and `:error`.

**Supply a block only when an argument cannot express the content.** `@labelField` picks the
field to display, `@selectedIcon` marks the chosen row, `@icon` puts a glyph in the trigger, and
`@noResultsLabel` rewords the empty state. A block that reproduces one of those is not neutral:
it costs behaviour (see `:selection` below) and it costs the reader a reason to look.

### What each block replaces

Every block lands **inside** markup the component keeps, so you supply content, not structure — the
option's `role`, its selected and disabled state, its ARIA position, the group header's label id,
the empty state's `role="status"` and the error state's `role="alert"` are all still handled for
you.

`:error` is yielded `reload` alongside the error, so a block that wants its own recovery control
can render one; the component's retry is shown only when no block is supplied.

`:item`, `:selection`, `:unresolved`, `:groupHeader`, `:groupFooter`, `:listHeader` and `:footer`
also yield the select's resolved options as their last parameter, so a recipe can render values
extensions override (see [Recipes](#recipes)).

`:groupHeader` and `:groupFooter` draw every header and footer row, text or action, and `:item`
never receives one, so `:item` stays about records. Tell the kinds apart by `onSelect`, which only
an action row carries; both carry `groupKey`, so one block can draw group-specific content for
either. `@groupHeader` (the builder) and `<:groupHeader>` (the block) share a name across separate
namespaces, and `<:groupFooter>` is unrelated to the panel's `<:footer>`.

### Blocks that interact

Two behaviours only appear once blocks are used together, and both are easy to get wrong:

- **`:footer` outlives the list.** It is a sibling of the async content rather than part of it,
  so it renders in every panel state — while loading, when populated, when empty, and when the
  source has failed. Gate its contents on the yielded `total`/`loadedCount` rather than assuming
  there are rows, or a footer will read "12 results" underneath "Nothing matches".
- **A `:groupHeader` or `:groupFooter` does not replace the option description.** Each option is
  `aria-describedby` a dedicated label span holding the builder's text for its group's text
  header, then its text footer; arbitrary custom markup, counts, and hints remain visible in the
  row without being repeated for every option. Keep a text footer short and about the group, since
  it is what repeats, and never end it with a bare number, which runs into the spoken position.
- **A group block never names an action row.** For an action header or footer, the builder's
  label (through `@labelField`) is the option's spoken name and the block's drawing is hidden
  from screen readers. So the label must contain the words the drawing shows (WCAG 2.5.3, label
  in name), and counts or hints in the drawing must not carry meaning the label lacks.

### Accessibility rules for block content

- Icons rendered through the icon helper are `aria-hidden` by default. Do not give one an
  `aria-label` in a row whose text already names it.
- Avatars and other decorative images need an empty `alt`, or the row's name is doubled.
- In an interactive multi-select chip, the accessible name is built from what `:selection`
  renders (the label span is hidden and pulled back in by the remove button). Display-only
  chips expose the label directly. An icon-only or image-only chip is
  announced as a bare remove button.
- Never render a trailing bare number; it is announced as part of the option's name ("performance
  871"). Use a phrase, or hide the visual figure and supply one.
- No interactive content in `:item`, `:groupHeader` or `:groupFooter`. In a text header or
  footer (`role="presentation"`) it cannot be reached from the keyboard; inside an option it is
  flattened into the name, and a click on it reaches the row's handler, so it runs the row's
  action. An action belongs in an action row returned by `@groupHeader` or `@groupFooter`.
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

## Extension points

Plugins and themes customize selects through one value transformer, `select-customizations`.
Its value is a registry, and each registration targets selects explicitly:

- `forAll(setup)` reaches every select.
- `forKind(kind, setup)` reaches selects whose `@kind` matches. A kind names what a select is,
  such as `"select-tag"`. Recipes set it.
- `forIdentifier(identifier, setup)` reaches selects whose `@identifier` matches. An identifier
  names one call site, such as `"composer-tags"`.

Names match exactly, and there is no inheritance or fan-out. A select has at most one kind and
one identifier, both fixed when it is created. `@identifier` is also the menu's identifier, so
selects that share one cannot be open together, and an identifier equal to another menu's closes
that menu when the select opens. Name kinds after the component and identifiers as
`<surface>-<role>`. Until cleanup, `@legacyKind` carries the replaced select-kit name(s) for the
deprecated `modifySelectKit` bridge and legacy root classes; it does not match `forKind`.

```js
import { trackedObject } from "@ember/reactive/collections";

api.registerValueTransformer("select-customizations", ({ value: selects }) => {
  selects.forKind("select-tag", (spec) => {
    // One state object per select: setup runs once for each matching select.
    const state = trackedObject({ suggesting: false });

    spec.content((items, { filter }) => {
      if (filter) {
        return items;
      }
      const toggle = {
        id: "suggestion-mode",
        name: i18n(state.suggesting ? "back" : "suggest"),
        onSelect(control) {
          state.suggesting = !state.suggesting;
          control.reload();
        },
      };
      return [toggle, ...items];
    });

    spec.load((load, { filter }) => {
      if (filter) {
        state.suggesting = false;
      }
      return state.suggesting ? loadSuggestions : load;
    });
  });

  selects.forIdentifier("composer-tags", (spec) =>
    spec.options((current, { instanceContext }) => ({
      disabled: instanceContext.locked,
    }))
  );
});
```

In this example `loadSuggestions` follows the same contract as `@load`, and the translation keys
name the Suggest and Back rows.

### Setup

- A matching setup runs once per select, when the select is created, as
  `setup(spec, { kind, identifier })`. Variables it declares belong to that select.
- Setups run from general to specific: `forAll`, then `forKind`, then `forIdentifier`, each in
  registration order. A call-site customization therefore overrides a kind-wide one.
- Setup only declares. It is synchronous and gets no control and no context data. A setup that
  throws or returns a promise is reported and skipped as a whole.
- The registry and each `spec` are sealed once setup ends, so a stored one throws when called
  later. Reading an unknown `spec` member throws.
- Register at boot, before any select is created. A select never sees a registration made after
  it was created.

### The points

Each method on `spec` appends a callback. Callbacks for the same point compose in setup order.

| Method | Runs | Callback |
|---|---|---|
| `content(fn)` | when the list is built | `(items, ctx) => items`. Returns the next list. |
| `row(fn)` | for each option row | `(row, ctx) => void`. Mutates `row.classes` and `row.title`. |
| `options(fn)` | when presentation is read | `(current, ctx) => partial`. Returns overrides. |
| `load(fn)` | once per query, `@load` selects only | `(load, ctx) => load`. Must return a function. |
| `change(fn)` | on each selection change | `(next, ctx)`. Call `next()` to continue. |

**`content`** returns a new list. Set `sticky: true` on an option to keep an action such as
"Suggest" visible at the top while the list scrolls. Sticky options lead the none row and
specials, stay outside groups, and keep their relative order. Headers and dividers ignore
`sticky`, and bottom actions belong in `:footer`. A result that is not an array is a development
assertion and otherwise leaves the list unchanged. Content changes are reflected in
`aria-setsize` and the announced count. On paged sources, the set is the declared total plus the
customizations' net change. Two reveals in a row that add no visible rows stop paging for that
query. The set is then sized by the rows shown, and the footer's `total` becomes undefined.
Otherwise, footer `total` and `loadedCount` remain source counts. A group's action header or
footer is an option too, so `aria-setsize` counts every one shown: with a declared total it grows
as pages add groups (40 + 2, then 40 + 5), and a reveal that only adds a footer announces one more
result. Paging never counts them. Legacy `modifySelectKit` content runs after every `content`
callback.

**`row`** gets a fresh `{ classes: [], title: undefined }` for each row. Classes are added after
the core classes, and falsy entries are ignored. `title` renders only when a callback sets it; an
item's own `title` field is never a tooltip. Rows include none, create and action rows, but not
group headers, dividers, chips or the trigger. The context adds `item` (the raw row item),
`selected` and `disabled` (which includes selection-cap restrictions). It has no `control`.

**`options`** overrides presentation. The core keys are `caretIcon` (a string or
`{ open, closed }`), `iconOnly`, `label`, `placeholder`, `searchPlaceholder`, `searchIcon`, `loadingLabel`, `icon`, `showCaret`,
`clearable`, `noneLabel` and `disabled`, plus the keys a recipe declares (see
[Recipes](#recipes)). `current` holds the values so far, starting from the call site's arguments.
Every key is last-wins except `disabled`, which can add a lock but never lift one. `iconOnly`
needs a label: without one it is ignored with a warning. A key that is neither core nor declared
warns in development and is ignored, and a non-object result is skipped. The values resolve once
per change in what they read, not once per row. The context has `value` and `control`, and no
`options`, because options cannot depend on themselves.

**`load`** receives the loader for a new query and returns the one to use. Remote work a
customization adds belongs here rather than in a row's `onSelect`: a pending loader shows the
loading skeleton (`loadingLabel` captions it, with a spinner, in place of one skeleton row), its
`signal` cancels a superseded request, and a rejection shows the error state. It runs when the
query's first page starts, outside render, and the returned loader handles every reveal of that
query. Its context includes `loadContext`, the query's snapshot of `@loadContext`. A filter
change starts a new query. A mode flip without a filter change needs a changed `@loadContext`
entry or `control.reload()`; otherwise it applies at the next query.

**`change`** wraps the controlled `@onChange`. Not calling `next()` vetoes the change, and calling
it later defers it. A deferred `next()` still checks whether the change was superseded, and a
second call does nothing. A middleware may be async, for example to `await next()` and then
`control.reload()`. The context adds `value` and `items`, the change being made, and `control`.
Legacy `modifySelectKit` `onChange` callbacks run as soon as the middleware chain returns, so a
deferred `next()` emits after them.

### Contexts

Every callback gets `kind` and `identifier`, the select's names (`undefined` when absent), and two
namespaces of outside data, so a key core adds later never collides with one a customization
relies on:

- `kindContext` comes from `@kindContext`, the recipe's raw state, such as its scope.
- `instanceContext` comes from `@instanceContext`, which a call site sets, such as the topic
  being edited. A recipe forwards the one it was given.

Both default to a frozen empty object, so `context.kindContext.scope` is always safe to read.
Derived values such as labels are recipe options, not `kindContext`.

`content`, `row`, `load` and `change` contexts also carry `options`, a frozen snapshot of the
resolved core and recipe values. A change middleware and the emit it lets through share one
snapshot, so a deferred `next()` emits the values the middleware saw.

`content`, `row` and `options` run while the list renders, so they must be pure. They must not
write tracked state or call `update()` or any control or scope verbs. Those are for event time,
such as a row's `onSelect`. A callback that reads tracked state runs again when that state
changes. `load` runs outside render and may update its own state, such as leaving a mode when the
query has a filter. Read `control.pending` in `content` to return a reactive loading row, for
example with `name: control.pending ? i18n("suggesting") : i18n("suggest")` and
`disabled: control.pending`.

### Errors

Every setup and callback runs through the transformer error handling: a failure is reported and
rethrown in tests. In production a failing setup is skipped, `content` and `load` keep the
previous value, `row` keeps what was already set, `options` skips that result, and a failing
`change` middleware falls through to `next()` unless it already called it. An error thrown by the
consumer's `@onChange` is never treated as a broken customization: it reaches the caller.

### The control

`control` is the select's handle. Action rows receive it as `onSelect(control, item)`, and the
`content`, `options`, `load` and `change` contexts carry it. It is the same frozen object for the
select's whole life. It exposes:

- `value`, `filter`, and tracked `pending` (whether async update work is in flight).
- `close()` to close the overlay.
- `select(item)` to set a single value or add a multi value.
- `selectMany(items)` to add a batch with one `change` middleware run and one `@onChange`.
  It skips disabled, action, structural, already-held and duplicate items, and truncates to
  the remaining `@maximum` capacity. It caches added items for display. Empty and locked
  batches emit nothing; even an all-held or fully capped batch supersedes older update work.
  A batch that adds nothing because its items were held or over the limit emits no change,
  but is announced ("All already selected", or the skipped count with its reason), pastes
  included.
  On a single-select it selects the first new eligible item.
- `deselect(item)` to remove a multi value, or clear a single value only if that item is held.
- `clear()` to clear a nonempty selection.
- `reload()` to start a new query, even with the same filter. It does not supersede a pending
  `update()`. Its loading state waits out the usual delay, so a fast answer never flashes a
  skeleton. `reload({ immediate: true })` shows it at once, for a reload that switches what the
  list shows (a toggle into or out of suggestions), where the rows on screen are already wrong.
  A loader that can answer synchronously (cached results) shows no loading state either way.
- `update(work)` to run synchronous or asynchronous work with a selection update scope.

The scope has an `AbortSignal` named `signal`, a pure `current` reader, and `select(item)`,
`selectMany(items)`, `deselect(item)`, and `clear()` verbs. Pass `scope.signal` to cancellable
requests so the engine can stop them when the update is superseded or the select is destroyed.
The signal is live during synchronous and asynchronous work and aborts with an `AbortError`
reason. The update's own scope writes and `control.reload()` do not abort it.
It has no `close()`, `reload()`, or `update()`. Inside `work`, call the scope's selection verbs.
Calling `control.select()`, `control.selectMany()`, `control.deselect()`, or `control.clear()` expresses external
selection intent and supersedes your own update. Scope writes use the normal selection rules,
including caps, `change` customizations, resolved-item caching, `@onChange`, and close-on-select;
they do nothing while locked or after the scope loses authority.

```js
onSelect: (control) => {
  const filter = control.filter;
  control.update(async (scope) => {
    control.close();
    const item = await suggest(filter, { signal: scope.signal });
    if (item) scope.select(item);
    else if (scope.current) noSuggestionsToast();
  }).catch((error) => {
    if (error.name !== "AbortError") popupAjaxError(error);
  });
},
```

Read `control.filter` before the first `await`, so later typing does not change the request's
input. Check `scope.current` before reporting a no-change outcome, such as a toast. If closing
after an `await`, use `if (scope.current) control.close()` so stale work cannot dismiss a newer
interaction. `update()` rejects when work throws or rejects, so catch the returned promise.

A newer update, any external selection intent (including a re-pick, removal, or clear), opening
a closed panel, or destruction supersedes the scope and aborts its signal. Closing and filter
resets and reloads do not. A parent value change can make `scope.current` false; a reordered
multi value counts as a change. Reading `current` does not abort the signal, and the scope can
become current again if the parent value changes back. An attempted write while stale
supersedes the scope. Once work ends, its scope is no longer current. A deferred
`change` commit may still finish after a normal end, but cannot commit after supersession.

While async work is pending, the trigger shows selection loading feedback and a spinner.
Synchronous work has no loading flash. Programmatic single sets and re-picks are announced;
multi adds and removals keep their item announcements, and clear announces "Selection cleared".
A batch announces one combined polite message: “3 added”, with “2 not added: already selected”
and/or “1 not added: over the limit” when applicable. Repeated batch items count as already
selected. Disabled, action and structural rows are silently skipped. Bulk feedback replaces
single-item feedback and suppresses the trailing result count.
No-change and superseded work announce no outcome, so extensions should announce their own
no-change result alongside a toast. Control methods do nothing once the select is destroyed.

### Parsing pastes

`@parsePaste(text, context)` receives plain clipboard text and a snapshot of `{ filter,
options, value }`. It runs on the desktop and mobile typeahead query inputs and the button
variant's filter. Return `null` or `undefined` to leave native paste untouched (for example,
for a single token), or an array of items to prevent native paste and call `selectMany`.
An accepted array clears the original query, including when the batch adds nothing.

```gjs
<DSelect
  @items={{this.items}}
  @multiple={{true}}
  @onChange={{this.onChange}}
  @parsePaste={{this.parsePaste}}
  @value={{this.value}}
/>
```

The parser may return a promise of an array or a nullish result. A promise prevents native
paste immediately and runs through `control.update()`, so a hand pick or newer selection
intent supersedes the parser. Parsing and batch middleware share one update scope, including
synchronous parsers. Query cleanup rechecks the scope after middleware and only clears the
same query in the same open session. Newer typing is preserved even if the batch still lands.
An asynchronous nullish result makes no selection change and leaves the query intact.

### Recipes

A recipe is a specialized `DSelect` for one kind of value, such as categories or tags. Recipes are
meant to live in `ui-kit/select/recipes/`. Recipes in this directory are the domain-specific
exception to the kit's domain-free primitives. A recipe:

- sets `@kind`, and passes `@kindContext` with its raw state;
- forwards the call site's `@identifier`, `@instanceContext`, `@items`, `@load` and `@onChange`,
  and its `:item`, `:selection` and `:footer` blocks;
- passes `@suppressFooter={{not (has-block "footer")}}` with a forwarded `:footer`. A forwarded
  block always counts as passed, so without it every recipe panel ends in an empty footer;
- never sets its own `@identifier`, which would take the call-site tier away from its callers.

#### What the engine already does

A recipe states its domain's rules and renders its rows. Before writing anything else, check this
list; if a need is missing from it and from the domain's model, ask before adding code.

Sources (`-internals/engine/select-sources.ts`):

- `@items` is a client source (`LocalSource`); `@load` is a server source (`PagedSource`), even
  when it answers synchronously.
- A `@load` that returns a plain array has returned the complete set. Return
  `{ items, total, hasMore, cursor }` only to page: the engine keeps the offset, the page number and
  the cursor, hands them back as `opts.offset`/`opts.page`/`opts.cursor`, and asks again on a
  reveal. A recipe never counts pages itself.
- Without `hasMore`, `total` decides whether more pages remain, and sizes the list for
  `aria-setsize`. An explicit `hasMore` wins, and `hasMore: false` ends paging. Return only the
  counted records: a row that belongs after a record, such as an action on its family, is a
  group footer the engine adds (see Grouping below), never a row in the page.
- Rows are de-duplicated by key across pages, and a response for a superseded query or reveal is
  dropped, so a loader never checks its `signal` or compares results.
- Rendering is windowed, so a long array costs only the rows on screen.
- A filter change waits the input delay only for a loader that answered with a promise
  (`-internals/coordinators/select-presenter-base.ts`). A recipe never sets `@debounce`.
- `@loadContext` is the loader's inputs: a changed entry reloads the list. Arrays compare by their
  elements, so an equal array derived afresh after a pick never does.

Grouping (`-internals/engine/list-composer.ts`):

- `@groupBy` groups the rows. A client source merges every row of a key; a `@load` source groups
  consecutive rows, so pages only append. Rows with no key form their own `undefined` group, and
  the builders return nothing for it. `@groupDividers={{false}}` drops the splitters between
  groups.
- `@groupHeader` and `@groupFooter` build each group's boundaries from its key and rows: text, an
  action row, or nothing. The engine keys, positions and describes them, and holds a paged
  source's last footer back until no more rows can load.

Selection (`d-select.gts`, `-internals/engine/list-composer.ts`):

- `@multiple` defaults to `false`. A recipe forwards it; it never flips the default.
- `@valueItems` gives items for held ids already in hand; `@resolveValues` resolves the rest,
  synchronously or not. The engine normalizes `@value`'s shape and the emitted ids' types.
- `@specialItems` adds recipe-owned rows ahead of the source's, from a snapshot of the filter
  and value. They are not de-duplicated against the source, so the source must leave them out.
- `@noneLabel` adds the single-select "none" row; `@maximum` and `@minimum` cap the selection
  and announce the limit.
- Held rows stay listed and marked as selected, which keeps the selection reachable for
  assistive technology. `@hideSelected` exists, but is not a default to copy from the old
  component.
- A row with `onSelect` is an action: `control.update(async (scope) => …)` runs its work, and
  `scope.selectMany` is a no-op once a later change supersedes it (`SelectUpdateScope` in
  `select-engine.ts`).

Presentation:

- `@caretIcon={{hash open closed}}` sets the caret, and customizations override it as the core
  `caretIcon` option (`-internals/coordinators/variant-presenter.ts`,
  `-internals/engine/customizations.ts`). A recipe never tracks open state to draw its own.
- `@label`, `@id`, `@describedBy` and `@placeholder` name and describe the control.
- `@kindOptions` declares only rules the engine has no option for.

Shared helpers outside the engine: `makeArray` (`lib/helpers.ts`) normalizes one-or-many values,
`removeAccents` (`lib/utilities.js`) folds accents, and the `ui-kit/helpers/` badges
(`dCategoryBadge`, `dDiscourseTag`) render domain rows. A domain model's statics, such as
`Category.findByIds`, `findByIdsOrLoad`, `asyncFindByIds`, `search`, `searchCategories`,
`matchesSearch` and `asyncFindDescendants`, answer lookups and searches; a recipe calls them instead of wrapping them in a `lib/*-source`
module.

#### Tag recipes

The tag family has three recipes, split by what the pick is for:

- **`DSelectTag`** (kind `select-tag`) picks tags to store on something: topic tags, settings,
  preferences, synonyms. `@value` takes tag objects or names; `@onChange` emits tag objects, or
  stored names with `@emit="names"` (the untranslated name even when search shows a translation).
  `@multiple={{false}}` holds one tag. Creation needs both `@allowCreate` and the site's
  permission. `@maximum` defaults to the site's tags-per-topic and `@maximum={{false}}` lifts it;
  a site limit of 0 blocks additions while keeping removal. Search options are
  `@categoryId`, `@ignoreRestrictions` (all tags, not only those usable on topics), `@exclude`,
  `@excludeSynonyms`, `@excludeTagsWithSynonyms` and `@suggestRecent`.
- **`DSelectTagFilter`** (kind `select-tag-filter`) narrows a topic list. Its value is a tag,
  `ALL_TAGS_ID` or `NO_TAG_ID` (exported by the module), or several tags with `@multiple` for
  intersections. It offers the "all tags" and "no tags" shortcuts and the top tags, and never
  navigates: the call site turns the pick into a URL. A single filter clears only through its
  "all tags" row; Backspace leaves it alone, since a stray key would otherwise change the page.
- **`DSelectTagGroup`** (kind `select-tag-group`) picks tag groups by name.

Held names resolve when the value changes. Search sends only known numeric ids, and a pending or
failed name lookup never holds up search; a completed lookup reloads an open list with the
resolved ids.

Until cleanup, each recipe sets a default `@legacyKind` (`tag-chooser`, `tag-drop` or
`tags-intersection-chooser` with `mini-tag-chooser`, and `tag-group-chooser` with
`tag-chooser`), and call sites that replaced other select-kit components pass their own (the
composer passes `mini-tag-chooser`).

`@exclude` tags are also sent to the server as selected, so results fill with usable tags and
one-per-group rules apply. A side effect, unchanged from select-kit: in the bulk "replace tag"
rows, tags that share a one-per-topic group with the other row's tag are not offered.

The default tag row renders new items with `d_select.create_item`. A custom `:item` block
owns that wording too; use the item's `isNew` flag to distinguish creation from existing tags.

#### Category recipes

The category family has two recipes:

- **`DSelectCategory`** (kind `select-category`) picks categories to store. `@value` takes ids,
  numeric strings or category records; `@onChange` emits records, or ids with `@emit="ids"`. It
  holds one category, like `DSelect`; `@multiple={{true}}` holds several. The rules:
  - `@permission`: `"see"` (the default) offers every visible category, `"create"` only those the
    user can post in.
  - `@uncategorized`: defaults to `true` when multiple, otherwise to the site's
    `allow_uncategorized_topics`.
  - `@subcategories={{false}}` offers top-level categories only.
  - `@exclude` lists categories that are never offered; a held one stays selected. A screen
    with several lists passes each list only the categories the other lists hold.
  - `@scope` and `@prioritize` are the composer's rules. While browsing, they act one level up:
    the category's parent and that parent's children.
  - `@disabledCategories` are shown only as disabled rows at the top, described as read-only,
    and stay listed while a search matches them. The composer passes the category a new topic
    started from but cannot be posted in.
  - `@placeholder` is the trigger text with no value. `@noneLabel` adds a selectable "none" row
    instead.
  - `@descriptions` defaults to single mode. `@showAncestors` adds ancestor badges to chips.
  - `@selectDescendants` (the default when multiple) groups a search of two or more characters
    by family and follows each family's category with a footer row that adds the category and
    every level below it, before the rest of the family. The footer draws the category's badge
    with its topic count and "+ Subcategories", and its label speaks the same words. A family
    gets a footer only when its own category is among the results, is not disabled, and has a
    descendant the list could offer.
- **`DSelectCategoryFilter`** (kind `select-category-filter`) narrows a topic list, one level at
  a time. Its value is a category, `ALL_CATEGORIES_ID` or `NO_CATEGORIES_ID` (exported by the
  module), and `@parentCategory` names the level. An empty level, or `ALL_CATEGORIES_ID` ("remove
  filter"), holds nothing and shows the level's name ("categories", "subcategories") as its
  placeholder, which `@placeholder` or a customization's `placeholder` replaces. The drop is named
  "Filter by: categories" or "Filter by: subcategories", and a held filter follows that name.
  `@noSubcategories` holds `NO_CATEGORIES_ID`, which then offers "remove filter" in its place.
  The filter never navigates; the call site routes the pick. The breadcrumbs pass the identifier
  `breadcrumb-category`.

The picker has one loader, `Category.searchCategories`, which answers from the site without a
request when every category is loaded and asks `/categories/search` otherwise. Both answers use
the same rules and order: browsing lists each category after its parent, siblings by topic count
(or by position when `fixed_category_positions_on_create` is on); a search ranks the server's way
and keeps each family together. A preloaded site answers synchronously with every match at once,
for the engine to window, so typing never waits for the input delay; a lazy site pages by
`opts.page`. The scope's own category and the read-only categories, which the search leaves out,
are special rows. Held ids resolve through `Category.asyncFindByIds`, and a family's footer walks
the tree through `Category.asyncFindDescendants`.

The drop browses and searches through `Category.searchCategories` on every site. A search spans
the whole site at the top level, or the parent's direct children below it, and ranks the
server's way. Browsing lists a level in the site's order (by topic count, or by position when
`fixed_category_positions` is on), and a lazy level pages as the list scrolls, so every category
is reachable. Both leave out the categories the user mutes only through a parent
(`rejectIndirectlyMuted`), the set the navigation drops from its own list; a category muted
directly stays.

Until cleanup, `DSelectCategory` defaults `@legacyKind` to `category-chooser` (single) or
`category-selector` (multiple), and the filter to `category-drop`. Call sites that replaced other
select-kit components pass their own: advanced search passes
`search-advanced-category-chooser` with `category-chooser`, and former multiple selectors pass
`multiple-categories-selector`.

A variant that only changes configuration, such as a chooser used by advanced search, is the same
kind with its own `@identifier`, not a new kind.

A recipe declares the values extensions may override with `@kindOptions`, a hash of its keys and
their base values:

```gjs
<DSelect
  @identifier={{@identifier}}
  @kind="select-example"
  @kindOptions={{hash shownRows=15}}
  @load={{this.load}}
  @onChange={{this.onChange}}
/>
```

- Declare a key only for a rule the engine has no option for. The caret, for one, is the core
  `caretIcon` (`@caretIcon={{hash open="angle-down" closed="angle-right"}}`), which extensions
  already override.
- `@kindOptions` requires `@kind`, and a key named like a core key asserts. A `null` value counts
  as absent, but the key stays declared.
- The keys are fixed when the select is created; their values stay live.
- Extensions override them with the same `spec.options` as core keys, through `forKind` (or
  `forIdentifier` for one call site). `current` starts from the recipe's base value.

The resolved options, core and recipe keys together, reach the recipe as a new last argument, so
existing arguments keep their positions:

- `@items` as a function is called as `items(options)`. A zero-argument function still works.
- `@load`, `@resolveValue` and `@resolveValues` get `options` on their second argument.
- `@onChange` gets `options` on its third argument, `{ origin, reason, options }`.
- `allowCreate`, `createItem`, `createUnresolvedItem`, `specialItems` (after its snapshot),
  `filterBy`, `groupBy`, `groupHeader` and `groupFooter` get it as their last argument.
- The `:item`, `:selection`, `:unresolved`, `:groupHeader`, `:groupFooter`, `:listHeader` and
  `:footer` blocks yield it as their
  last parameter.

Code outside `DSelect`, such as markup around it, cannot read the resolved values.

Use `@multiple={{false}}` for single fields. A call site that stores an array adapts between
the recipe's single value and its array boundary; FormKit's tag chooser does this when its
maximum is one.

## Capability parity & gaps

This tracks DSelect against the behaviors it must eventually cover. It is intentionally honest
about what is not built yet, so a consumer can tell "use it" from "not ready." Describe entries
by mechanism.

### Covered

- Single and multiple selection, with chips and per-chip removal (`@multiple`).
- A first-class "none" row on single-select (`@noneLabel`): a selectable list row that clears the
  value to `null` and reads as selected while nothing is chosen. Always present while browsing, and
  filtered out under an active query so a non-matching search still reaches the empty state.
- Client (`@items`) and server (`@load`) sources; true pagination with tail reveal and an
  optional server row ceiling (`@maxLoaded`, uncapped by default); opaque paging cursors;
  `@filterBy` field or predicate; `@minChars` gate; `@debounce` (filter changes only; reveals
  and reloads fetch at once). By default a server source waits the input delay, unless its
  loader last answered without a promise; a synchronous `@load` filters at once, so a recipe
  never needs to toggle `@debounce` itself.
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
- Per-item `disabled`: arrow keys, Home/End and PageUp/PageDown reach every option, including
  item-disabled and cap-disabled rows. They keep `aria-disabled="true"` and cannot be activated
  by Enter or click. Entry seeding and typeahead auto-highlight still skip disabled rows.
- Per-item `description` (string): visible secondary text inside the option, referenced through
  `aria-describedby` alongside its group header. It is excluded from the option's accessible
  name and also renders with a custom `:item` block.
- Per-item action rows (`onSelect(control, item)`, which run instead of
  selecting and keep the overlay open unless the row calls `control.close()`).
- Per-item `sticky: true` for leading rows that stay visible while scrolling, such as a
  "Suggest" action. They remain options in the same listbox and participate in keyboard
  navigation. Use `:footer` for bottom actions.
- Selected-row indicator (`@selectedIcon`): shown always in multi-select (default check) and, in
  single-select, when the arg is set.
- Trigger variants (`@variant`: typeahead / button / static); a leading `@icon`; a label-less
  icon-only trigger on the button/static variants (`@iconOnly`, which needs a resolved label for
  the accessible name and is ignored with a warning without one; drive `@icon` from `@value` for
  a selection-reactive glyph); caret swap
  (`@caretIcon`) and caret suppression (`@showCaret={{false}}`); a trailing `@searchIcon` in a
  search field that is not the trigger (the `button` panel's field, the mobile modal's, and
  DSelectList's; never a desktop `typeahead` trigger, and `static` has no search); `@clearable`; `@disabled` /
  `@readonly`; overlay placement (`@placement` / `@offset`); `@onShow` / `@onClose`.
- Custom row and selection markup (`:item` / `:selection` blocks; on the typeahead variant the
  `:selection` block is the resting/closed display — once the menu opens the built-in input shows
  the editable label text, so it is not a live-while-editing surface); empty state
  (`@noResultsLabel` / `:empty`); loading skeleton (`@skeletonCount`, and a `:skeletonItem` block
  for one placeholder row); a muted source-error state with an optional retry (`@retryable`) and an
  `:error` consumer block.
- A fixed `:footer` block below the option list (labels, links, action buttons), keyboard-reachable,
  and a `:listHeader` block between the search field and the results, outside the listbox. Both
  yield live state `{filter, query, pending, showingSkeleton, value, hasValue, total, loadedCount,
  maximum, minimum, atMaximum, belowMinimum, remaining, close}` so their content can react (e.g. a
  "plus N more" from `total - loadedCount`). The search fields are described under `DSelectList`.
- `@hideSelected` omits held options from the results without reloading. Held items stay reachable
  as chips; a local static list shows its strip of held items instead. `@panelChips` lists held
  items in the panel even where the rows already show them (see "The panel field").
- Selection limits (`@maximum` / `@minimum`, multi-select). `@maximum` is a hard cap enforced at the
  engine's single `select()` chokepoint (so pointer, keyboard, create-on-the-fly, and the compat
  bridge are all covered) and reinforced by disabling every unselected option at the cap. Action
  rows stay open at the cap because they never become a value, except a group's action header
  or footer, which acts by adding rows and so closes like an option; a value
  seeded over the cap is displayed and removable, never trimmed. Pass `@maximum={{false}}` for no
  cap. Numbers below 1 and NaN also mean no cap, with a once-per-select development warning.
  `@minimum` is advisory (message + state only, never blocks removal — the consuming form owns
  submit-time enforcement). A built-in limit message renders in a dedicated top zone of the panel
  (never stacking with the footer or an error body). Cap-disabled options also reference this message through `aria-describedby`,
  alongside any item description and group header. The limit state is exposed on the engine and
  yielded to `:footer`.
- Customization through one `select-customizations` transformer targeting `@kind` or
  `@identifier` (content, rows, presentation options, loading and change, see
  [Extension points](#extension-points)); recipe options through `@kindOptions`; plus richer
  screen-reader announcements than the legacy family.
- Groups via `@groupBy` (a field name or `(item, options) => key`). Grouping runs after filtering
  on every render, so an empty group draws nothing and boundaries are always recomputed. A client
  (`@items`) source merges every row of a key into one group, in first-appearance order. A `@load`
  source groups consecutive rows instead, so a later page only ever appends: it extends the last
  group or starts new ones, and a key that comes back later starts another group. Return a
  family's rows together to keep it in one group. Groups are found before held rows are hidden,
  so selecting never renumbers them.

  Each group may have a header and a footer, built by `@groupHeader` and `@groupFooter` from
  `(key, rows, options)`, where `rows` are the group's surviving rows, frozen. Either builder
  returns text (a `role="presentation"` row), an action row (an item with `onSelect`, rendered as
  a navigable option and copied without `sticky`), or nothing; anything else is a development
  assertion. Builders run during render, so they must be pure, and they return nothing for an
  `undefined` key. A group with no header of either kind gets an unlabeled splitter instead, a
  purely visual rule that is suppressed at the head of the list. `@groupDividers={{false}}` turns
  splitters off, for groups whose footers already mark where each one ends; positions, set sizes
  and footers are unchanged. Like `@groupBy`, it is read once when the select is built.

  For a `@load` source, the last group's footer waits until no more rows can load (the source is
  exhausted, either brake stopped paging, or `@maxLoaded` was reached), so a page that continues
  that group adds rows above a footer that is not there yet instead of pushing one down. Its
  builder is not called until then, and after a `@maxLoaded` stop its `rows` hold only the loaded
  part. A header on that group sees only the rows loaded so far, so a whole-group action belongs
  in a footer. Across pages a builder must keep each boundary's presence and kind, changing only
  its contents; a development warning flags a change, since it would shift rows already shown.

  After a search the cursor starts on the first activatable row. An action header leading the
  results is therefore where it starts, and Enter runs it; use a footer when Enter should pick a
  record. An action footer is where it starts only when every row before it is held or disabled.

  Each option in a group with a text header or text footer references their id-bearing label
  spans through `aria-describedby`, header first. A group with neither carries no group
  description, and action rows name their group themselves: so an action header, or an action
  footer without a text header, must name its group. Use a text header when the options need the
  group's name. The window extension keeps a group's text header and footer mounted while any of
  its rows are mounted, so descriptions resolve for every published window and the description
  DOM stays bounded by the window size by construction, even under near-unique `@groupBy`. The
  label span contains only the builder's text and is hidden when a custom `:groupHeader` or
  `:groupFooter` renders, keeping arbitrary block markup out of option descriptions. The engine
  still rejects a string `@groupBy` that names the value field outright.

  The previous mechanism resolved ID references on every rendered frame; keeping headers mounted
  guarantees them for every published window. During the one-runloop transient after an items change (the
  same stale-window interval covered by the `{{#if descriptor}}` row guard), a regrouped option
  can briefly reference a header outside the stale mounted set. Assistive technology treats that
  unresolvable ID reference as no description for that runloop.
  `aria-posinset`/`aria-setsize` stay global across groups: per-group numbering carries no
  meaning without nested `role="group"` semantics, which a windowed flat list cannot preserve.
  (The APG-sanctioned structure nests a `role="group"` with `aria-labelledby` between the
  listbox and its options; our flat virtualizer can't window nested group containers, so the
  flat association is the sanctioned fallback — nested groups are a follow-up.)
  **Invariant:** all structural rows are engine-injected. The `__header`/`__footer`/`__divider`
  fields on `SelectItem` (and the `__groupHeader`/`__groupFooter` stamps on action copies) are
  engine plumbing with no public constructor — never supply them in `@items`,
  `@load`, or `@specialItems` (grouping discards upstream structural rows and derives its own
  structure); those inputs must be selectable options.

### Missing (scheduled)

- **Nested `role="group"` grouping semantics** — the APG-sanctioned optgroup structure (a
  `role="group"` + `aria-labelledby` wrapping each group's options, kept even under virtualization,
  which is what a windowed listbox has to preserve for the structure to mean anything). Requires
  the windowing primitive to position nested group containers; the current flat list uses the
  `aria-describedby` fallback instead.
- **Group-exclusive (radio) selection** — a multi-select where picking an option evicts its
  group-mates from the value. Designed, not implemented: see
  `docs/select-kit-replacement/RADIO-GROUPS-DESIGN.md`.
- **Misc knobs** — hidden native form input; hidden-value exclusion; autofocus / open-on-render;
  a consumer keydown boundary hook; filter icon.

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
- **Full component overrides** — swapping the trigger, filter, or per-row component wholesale is
  intentionally not offered; customization is the headless engine plus the `:item` / `:selection`
  blocks.
- **Legacy compatibility bridge** — `-internals/modify-select-kit-bridge.ts` is a migration aid,
  deprecated, and slated for removal, not a kept API.

## DSelectList

Use `DSelectList` for a persistent search and selection surface inside a panel, or for
several independent selects inside one `DMenu`. It is always multi: pass an array to
`@value` and replace it with the array from `@onChange(next, items, change)`. It shares
DSelect's sources, creation, paste parsing, customizations, selection limits and value
resolution. It has no trigger, overlay lifecycle callbacks or mobile modal.

`@virtualized` defaults to `true`: the windowed body handles large result sets and
pagination. Set `@virtualized={{false}}` for a short list whose rows need normal flow,
including wrapping pills. The static body mounts every loaded row and never paginates;
a paginating source warns in debug and only its first page is shown. Both bodies scroll
within `--d-select-list-max-height` (default `20em`).
After the loading-feedback delay, the static body replaces each displayed row with
an inert `li.d-select__option.--placeholder` containing a text skeleton in the same
`ul.d-select__options`, marked `aria-busy="true"`. Its first load uses the same row
markup. Virtualized lists keep the separate skeleton list.

`@hideSelected` leaves held items as chips in the search field and omits them from
results.
Removing a chip restores its row without another source request. Rows then drop the
selection marker, which could only ever read unselected. The `:listHeader`
block sits between the search field and results, outside the listbox. It yields the same live
state and resolved options as `:footer`, so a suggested-results heading can show only
when `state.query` is empty. Four fields describe a search, the same way in DSelect:

- `state.filter` is the text in the search field right now.
- `state.query` is the search the visible results are for. While a new search loads, the
  previous results stay on screen and `query` keeps naming their search until the new
  results arrive.
- `state.pending` is true while results are loading (a new search, a reload or the next
  page), from the moment the load starts; for a search, that is the keystroke.
- `state.showingSkeleton` turns true once a search, a reload or the first load runs past the
  loading-feedback delay and skeleton rows replace the results; `query` then names the last
  search that finished. Placeholder rows added below results for the next page do not count.

This works with async `@load` sources. Unlike DSelect's, neither state has a `close`
action. Other blocks are `:item`, `:selection`, `:selectionLoading`,
`:unresolved`, `:empty` and `:error`; see the typed signature in `d-select-list.gts` for
their yielded values. Held values resolve through `@resolveValues`, `@resolveValue` or
`@valueItems`, as in DSelect.

Nothing takes focus on render. A row press first focuses this select's search and keeps
it there, including when another select previously held focus. The search field and its
chips follow [the panel field](#the-panel-field) model. In a static list PageUp/PageDown
jump to the first/last option, since every row is mounted. Tab visits the search field,
footer controls, then the next control; neither the chips nor the listbox are Tab
stops. Escape clears a non-empty query and is otherwise left to the containing panel,
including a `DMenu`.

Automatic cursor entry needs focus inside the root, a query and room below the cap.
Blur clears the cursor and pending jumps while preserving the query; returning with
a query re-seeds it. List-state speech is restricted to the focused select, with a
second ownership check for deferred reports. Adds and removals always speak. Empty
and error content remains visible while unfocused without live-region roles. An
empty query with no rows renders and speaks no empty-result message.

`@label`, `@searchPlaceholder` (default “Search…”), `@searchIcon` (a trailing glyph), `@id`, `@describedBy`, `@invalid`,
`@disabled` and `@readonly` apply to the search input. Its `aria-controls` exists only
while a listbox renders. The root is `.d-select.--list`, takes `...attributes`, and
exposes the same `data-select-id`, `data-value` and `data-name` hooks as DSelect.
`dSelect()` and `PageObjects::Components::UiKit::DSelect.at` accept this root too.

The styleguide's “Two lists in one panel” example uses async tag sources, wrapping
suggestions, a suggested-results header, and a checkbox that mounts the second list.
“Clear all” belongs to that containing panel, which owns both controlled selections.
