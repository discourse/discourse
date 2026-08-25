# DReorderableList

One component (`../d-reorderable-list.gts`) over focused collaborators in
`-internals/`. Consumers import only `discourse/ui-kit/d-reorderable-list` and
`discourse/ui-kit/d-reorderable-list-group`; nothing outside this directory
imports from `-internals/`.

The component owns the whole interaction — keyed iteration, the drag handle, the
move menu, the keyboard path, boundary state, drop normalization, no-op
suppression, focus restoration and the announcement — so a surface supplies row
content and one `@onMove` that projects the proposed order into its own store.

See the argument reference in the `Args` block of `types.ts`.

## Architecture

- **`types.ts`** — every interface, including the four the component re-exports
  as its public surface (`ReorderableMove`, `ReorderableRowApi`,
  `ReorderableGroupMember`, `ReorderableGroupApi`). It is a documentation home
  as much as a type home. The re-export is what `d-reorderable-list-group.gts`
  imports from, and `type-tests/ui-kit/d-reorderable-list-test.gts` is the only
  thing that would notice if it were dropped.
- **`-internals/engine/move-engine.ts`** — the move algebra. Every input method
  and both drag paths funnel into `commitSeqMove`, so there is one place that
  calls the consumer back and one that announces. Also owns `removalProjection`,
  the view of this list with one row taken out that a sibling member resolves a
  cross-list drop against.
- **`-internals/coordinators/reorder-announcer.ts`** — everything the list says
  out loud, and therefore the chord-run state and its settle timer.
- **`-internals/coordinators/move-menu-coordinator.ts`** — the single menu
  instance, re-anchored per row rather than built per row, plus the open/close
  protocol and the menu-driven moves.
- **`-internals/parts/`** — the rendering subcomponents: `handle`, `remove`,
  `create-row`, and `move-menu` (which carries `MoveItem`).
- **`-internals/constants.ts`** — shared by the coordinator and by the keyboard
  modifier that stayed on the component. Import it; do not restate the values.
  The menu identifier is load-bearing in two places at once, and a copy that
  drifts closes the menu on its own focus.

Collaborators are plain classes, constructed once by the component and
configured downward with thunks. They never hold a component reference.

## Two things that will bite

**A collaborator must be an `associateDestroyableChild`.** `isDestroying(x)` is a
lookup in a registry, so on a plain object nobody registered it returns `false`
forever. A guard written without the association reads as a fix, passes review
and does nothing; a `registerDestructor` on it never fires.

**Arguments are read through thunks, never captured.** `@label`, `@listLabel`,
`@movable`, `@removable` and `@onMove` are all read per call today. Capturing one
at construction breaks nothing any existing test can see — none of them swaps an
argument after the first render except the one written to catch exactly this —
and breaks the day a consumer passes a getter-produced closure.

## Where things deliberately did not go

`#keyFor` and the `rows` projection stay on the component: the engine is not
their caller, and `rows` carries no `@cached`.

`#refocusRow` stays on the component because it resolves against the element the
keyboard modifier installs on. An engine holding that element would have
captured `null` at construction and fallen back to a document-wide query, which
lands on the wrong list as soon as two index-keyed members share a key.

The announcement is gated by the dispatch, not by the announcer. An engine that
called the announcer unconditionally would silently un-veto an `@onMove` that
returned `false`.

## Announcements

`reorder.at_start` and `reorder.at_end` are built from the refused direction, so
neither key appears as a literal anywhere. A grep for them finds nothing, and
nothing detects an unused translation key. They are live.
