# DReorderableList

Maintainer notes. They describe how the component is split across files, the
invariants those files share, and why some code lives where it does. For usage,
see the `Args` block in `types.ts` and the styleguide examples under Molecules.

`d-reorderable-list.gts` is the entry, and `d-reorderable-list-group.gts` joins
several lists. Those two are the only import paths. This directory holds the
collaborators the entry renders with. Outside this directory, only the entry and
the internals' own unit tests import from `-internals/`.

The component owns the whole interaction: keyed iteration, the drag handle, the
move menu, the keyboard path, drop normalization, focus restoration and the
announcement. A surface supplies row content and one `@onMove` that projects the
proposed order into its own store.

| File | Owns |
| --- | --- |
| `types.ts` | Every interface, including the four the entry re-exports as public API. The group imports them through that re-export. |
| `-internals/engine/move-engine.ts` | The move algebra. Every input method funnels into `commitSeqMove`, so one place calls the consumer back and one place announces. Also `removalProjection`, which a sibling list resolves a cross-list drop against. |
| `-internals/coordinators/reorder-announcer.ts` | Everything the list says out loud, including the chord-run state and its settle timer. |
| `-internals/coordinators/move-menu-coordinator.ts` | The single menu instance, re-anchored per row, and the moves made from it. |
| `-internals/parts/` | The rendering subcomponents: `handle`, `remove`, `create-row` and `move-menu`. |
| `-internals/constants.ts` | Values that more than one file must agree on. |

## Invariants that cross these files

**Collaborators are destroyable children of the component.** They are plain
classes, built once in the constructor. `isDestroying` only reports `true` for
an object linked into Ember's destroyable tree, so the announcer and the menu
coordinator are passed to `associateDestroyableChild`. Without that link, their
destroyed-guards never trip and their `registerDestructor` callbacks never run.

**Collaborators read arguments through thunks.** Each one receives
`() => this.args` and reads it at the moment it needs a value. Copying an
argument at construction would still pass a first render, then go stale when the
consumer changes it. The group registration is the most exposed case: a copied
`listLabel` would leave a renamed list under its old name in its siblings' move
menus.

**A removal is confirmed before it is announced.** `onRemove` awaits the
consumer's handler, then checks that the row actually left. A consumer may put a
confirmation in front of the removal. Announcing straight away would speak over
a row that is still on screen, and would be wrong if the reader cancels.

**The menu identifier comes from `constants.ts`.** The coordinator opens the menu
under it, and the entry uses it to recognize focus inside the open menu. A copy
that drifts makes the list treat the menu's own focus as focus leaving, which
closes the menu.

## Nesting

Lists can nest, and two mechanisms reach past their own list unless told not to.

The keyboard listener runs in the **capture** phase, so an outer list sees an
inner list's keys first. A gate at the top of the handler ignores keys from any
other list's rows. Without it the outer list would answer them, and because the
chord path stops propagation, the inner list would never see them.

`ItemScope` queries from the list root, so it also finds a nested list's
handles. Anything that walks the DOM filters to elements whose nearest
`.d-reorderable-list` ancestor is this list's root. `#refocusIndex` avoids the
question by reading the handle registry, which only holds this list's handles.

## Spill

`@spill` lets a row refused at one list's end continue into the adjacent list.
`MoveEngine.spillTarget` decides whether there is one, and the menu asks it the
same question, so the menu and the keyboard always offer the same step.

The group resolves "adjacent" in **document order**, not screen position. It
does not lay out its members, and a wrapped group can be side by side at one
width and stacked at another. That is why `neighbour` takes `"previous"` and
`"next"` rather than `"up"` and `"down"`. It is also why `@spill` is opt-in:
turning it on asserts that the lists run top to bottom in reading order.

## Deliberately kept on the component

`#keyFor` and the `rows` projection stay on the component, because the engine
does not call them. `rows` has no `@cached`.

`#refocusIndex` stays because it resolves against the element the keyboard
modifier installs on. That element does not exist yet when the engine is built,
so an engine holding it would fall back to a document-wide query. That query
finds the wrong list as soon as two index-keyed lists share a key.

The dispatch decides whether to announce, not the announcer. An engine that
always announced would speak a move that `@onMove` vetoed by returning `false`.

## Announcements

`reorder.at_start` and `reorder.at_end` are built from the refused direction, so
neither key appears as a literal in the code. A search for them only finds the
comment in `reorder-announcer.ts` that marks them as live. Do not delete them as
unused.
