# DCarousel

`d-carousel.gts` is the entry and the only import path. This directory holds
the collaborators it renders with.

| File | Owns |
| --- | --- |
| `types.ts` | The public signatures and the argument reference the entry points at. |
| `-internals/parts/track.gts` | The scroll-snapping viewport, the keyboard surface, and the scroll tracking hook. |
| `-internals/parts/slide.gts` | One slide and its registration under the consumer's key. |
| `-internals/parts/controls.gts` | The navigation row, absent while there is a single slide. |
| `-internals/parts/nav-button.gts` | The step button curried into `Previous` and `Next`. |
| `-internals/parts/dots.gts`, `dot.gts` | The dot row and one dot per slide. |
| `-internals/parts/counter.gts` | The "position / total" readout that replaces the dots past ten slides. |

## Invariants that cross these files

**Track order comes from the DOM, not from registration.** The registry is a
`Map` keyed by the consumer's slide key, and its insertion order is the order
the modifiers installed in. A slide inserted between two others registers last,
so paging from the map would skip around the visible order. Every ordered read
sorts the registered elements by `compareDocumentPosition` instead, and the
sort is deliberately not cached: a reorder moves elements without touching the
registry, so a cached order would be stale until the next registration.

**Tracked writes from modifiers are deferred one hop.** A modifier installing
during render cannot write tracked state that the same render already read, so
`registerSlide` schedules its version bump to `afterRender`. Static analysis
will suggest the deferral is unnecessary. It is not; removing it trips the
backtracking assertion.

**Cleanups are identity-guarded.** Ember defers destructors, so a cleanup can
run *after* its successor has already registered under the same key. Every
teardown checks that the entry still points at its own element before clearing
it.

**The active slide is reconciled only when scrolling settles.** `scrollToKey`
sets the active key immediately so the dots respond to the click, and the
track's `scrollend` listener (or a settle timer where the event is missing)
confirms whichever slide ended nearest the centre. Reconciling on every scroll
event would flip the active slide back and forth through the intermediate
positions of a smooth scroll.

**Every tracked read of the registry consumes the version tag.** The `void
this._slidesVersion` lines are what make the getters recompute when a slide
registers or leaves, including the case where the active slide itself is
removed and the active key must fall back to the first slide.

## Deliberately absent

There is no `@onChange` argument. The bag yields `activeKey`, `activeIndex`,
and `count`, so a consumer that wants to react to paging reads them where it
renders; a callback would duplicate that surface.

Dots and the counter choose themselves. `Dots` renders only up to ten slides and
`Counter` only beyond that, so a consumer places both and exactly one shows. A
consumer that wants a different indicator renders its own from the yielded
state.
