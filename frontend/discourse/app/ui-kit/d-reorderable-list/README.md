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

## Nesting

Lists nest wherever the things being ordered do, and two of the component's
mechanisms reach past their own list unless told not to.

The keyboard modifier listens in the **capture** phase, so an outer list sees an
inner list's keys first. Every handle matches the cursor selector regardless of
which list it belongs to, and the chord path stops propagation, so without the
ownership gate at the top of the handler an ancestor answers for a descendant's
keys and the list the reader is actually in never receives them at all.

`ItemScope` is a plain `querySelectorAll` from the root, so a nested list's
handles are inside it. Anything walking the DOM here — the cursor, the removal
successor, the row a click focuses — filters to elements whose nearest
`.d-reorderable-list` ancestor is this list's own root. `#refocusIndex` sidesteps
the question entirely by reading the handle registry, which holds only handles
this list registered.

## Two things that will bite

**A collaborator must be an `associateDestroyableChild`.** `isDestroying(x)` is a
lookup in a registry, so on a plain object nobody registered it returns `false`
forever. A guard written without the association reads as a fix, passes review
and does nothing; a `registerDestructor` on it never fires.

**Arguments are read through thunks, never captured.** `@label`, `@listLabel`,
`@movable`, `@removable` and `@onMove` are all read per call today. Capturing one
at construction breaks nothing any existing test can see — none of them swaps an
argument after the first render except the ones written to catch exactly this —
and breaks the day a consumer passes a getter-produced closure. The group member
registration is the place this went wrong once: every field on it is a closure,
and `listLabel` was a snapshot, so a list the reader could rename stood in its
siblings' menus under its old name while the announcement used the new one.

**A removal is verified, not assumed.** `onRemove` awaits whatever the handler
returns and then checks that an item actually went before announcing and
re-placing focus. A consumer with a confirmation in front of the removal is back
before the reader has answered, so announcing on the call speaks over a row still
on screen and lies outright when they cancel.

## Where things deliberately did not go

`#keyFor` and the `rows` projection stay on the component: the engine is not
their caller, and `rows` carries no `@cached`.

`#refocusIndex` stays on the component because it resolves against the element the
keyboard modifier installs on. An engine holding that element would have
captured `null` at construction and fallen back to a document-wide query, which
lands on the wrong list as soon as two index-keyed members share a key.

The announcement is gated by the dispatch, not by the announcer. An engine that
called the announcer unconditionally would silently un-veto an `@onMove` that
returned `false`.

## Spill

`@spill` lets a row refused at a member's end carry on into the adjacent member
rather than stopping. `MoveEngine.spillTarget` decides whether there is one and
the menu asks it the same question, so the step the menu offers and the step the
accelerator takes never disagree.

The group resolves "adjacent" in **document order**, not on screen: it does not
lay its members out and cannot see where they landed, and a flex-wrapped group is
side by side at one width and stacked at another. That is why `neighbour` takes
`"previous"`/`"next"` rather than `"up"`/`"down"` — the spatial words are true of
a row inside its own vertical list and nowhere else — and why `@spill` is opt-in:
switching it on is the consumer asserting that its members run top to bottom in
reading order.

## Announcements

`reorder.at_start` and `reorder.at_end` are built from the refused direction, so
neither key appears as a literal anywhere. A grep for them finds nothing, and
nothing detects an unused translation key. They are live.
