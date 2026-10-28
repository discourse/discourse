# DTabs

`d-tabs.gts` is the entry and the only import path. This directory holds the
collaborators it renders with.

| File | Owns |
| --- | --- |
| `types.ts` | The public signatures and the argument reference the entry points at. |
| `-internals/parts/tablist.gts` | The `role="tablist"` element, the keyboard engine, and the scroll strip wrapped around it. |
| `-internals/parts/tab.gts` | One `role="tab"` button, and the guard that makes a disabled tab inert. |

## Invariants that cross these files

**One portal, rendered once.** The tablist part registers its element into
tracked state, and the entry portals the *whole* declaration block into it in a
single `{{#in-element}}`. Each `tabs.Tab` then renders its button in place, so
declaration order is DOM order by construction rather than by sorting. Splitting
this into a portal per tab would reintroduce the ordering problem it exists to
avoid.

**Nothing renders until the tablist exists.** The portal target starts `null`, so
a `<:header>` block that never places the yielded `Tablist` renders no tabs at
all rather than falling back to a strip of its own. A DEBUG assert after the
first render catches that, because the failure is otherwise total and silent:
the widget renders the header's own markup and an empty panel. Placement is
therefore required on the first render, not merely eventually.

**Tracked writes from modifiers are deferred one hop.** A modifier installing
during render cannot write tracked state that the same render already read, so
the register modifiers schedule their writes to `afterRender` and keep untracked
mirrors (`#tablistActual`, `#panelActual`) for anything that must read the value
synchronously. Static analysis will suggest the deferral is unnecessary. It is
not; removing it trips the backtracking assertion.

**Cleanups are identity-guarded.** Ember defers destructors, so a cleanup can run
*after* its successor has already registered. Every `register*` teardown checks
that the entry still points at its own element before clearing it.

**Keys round-trip by element identity, not by attribute.** `data-d-tab` is the
key stringified. Reading it back would hand a consumer with non-string keys a
different value from the keyboard than from a click, so the registry is consulted
by element instead. The keys a consumer supplies never become DOM ids either:
the widget mints its own, which is why two groups may reuse the same key.

**The panel is mounted once and never replaced.** Content is portalled into it in
append mode, which never clears the target, so there is no swap race. Activation
resets its scroll offset and rescues focus if the outgoing content held it.

## Deliberately absent

There is no `@activation` argument. Arrow keys move focus without selecting, and
automatic activation would land additively through the keyboard engine's own
`onActiveChange` rather than as a placeholder argument here.
