# Coming next — finish the kernel dissolution

Status: IN PROGRESS. Supersedes the "publish/save/discard is not extractable"
note in memory, which was too conservative.

## Progress + FINAL NAMES (locked 2026-06-29)

- **D-Cycle 1 — fold strays — DONE** (`991d0d8a074`).
- **D-Cycle 2 — drop dispatch → `wireframe-drop-dispatch` — DONE** (`3593e33027a`).
- **D-Cycle 3 — publish/draft layer → NEW `wireframe-staging` — NEXT** (deep-planned
  + adversarially reviewed; see "Cycle 3" below — read `wireframe-publish` there as
  the now-final `wireframe-staging`).
- **D-Cycle 4 — rename the kernel `wireframe` → `wireframe-workspace`** (separate
  focused commit after D3; ~5 consumer files post-sweep).

End-state trio (resolves the old `wireframe`-vs-`wireframe-edit-mode` ambiguity):
`wireframe-workspace` = the editor (open/close, chrome, orchestration) ·
`wireframe-edit-mode` = the is-open/can-edit signal (leaf) ·
`wireframe-staging` = the in-session draft layer + publish/save/discard (NEW).
The "staging" name was chosen over `wireframe-publish` to avoid colliding with
`wireframe-live-layout` (the live publish I/O) and `wireframe-publish-preview` (the
diff read-model); staging = where edits accumulate before publish/save/discard.

## Goal

Shrink `services/wireframe.js` from ~1300 LOC to a **thin orchestrator (~100–150 LOC)**
with one defined concern: **editor session lifecycle** (open/close the session,
sequence the cross-concern setup/teardown). Everything else moves to an owning
service — reusing existing services wherever the dependency graph allows, adding
**two** new services (`wireframe-drop-dispatch`, `wireframe-publish`), each a genuine
concern with no existing home.

Non-goal: deleting `wireframe.js` entirely. `enter()`/`exit()` is an ordered,
atomic, cross-concern transaction (theme→materialize→register-dispatcher→render-swap
→listeners→hydrate). Distributing it as pub/sub choreography loses that ordering
guarantee. A thin *orchestrator* that sequences it is the correct terminal form —
"the coordinator role is gone, not the file."

## DAG constraints (verified, load-bearing)

- No peer service injects `@service wireframe` — the kernel is top-of-DAG.
- `dropAuthority` injects `wireframeDragSession`; `blockMutations` injects
  `dropAuthority`; `gridManipulator` injects `blockMutations`. ⇒ **anything owning
  `runDropDispatch` (which calls blockMutations + gridManipulator) cannot be
  injected by dragSession/dropAuthority/blockMutations/gridManipulator.** dragSession
  and dragOverlay are therefore disqualified from owning the dispatch table.
- `wireframeDragSession`, `wireframeDragOverlay`, `wireframeEditMode` are
  dependency-free.
- `wireframeClipboard` injects editEngine+layoutQuery+selection (cutSelected needs
  +blockMutations — acyclic, nothing injects clipboard).
- `wireframeEntryConfig` injects editEngine+layoutQuery+selection (exactly what
  updateSelectedContainerArg needs).
- `wireframeSelection` injects revision+layoutQuery (deselect fold needs +session —
  acyclic, session is dependency-free).

## Where each remaining cluster goes (reuse-first)

| Cluster (file:line) | Home | New service? |
|---|---|---|
| `notifyChromeInserted` (540), `flashBlock` (552) — block-reveal facades (overlooked) | `wireframeBlockReveal` | no |
| `cutSelected` (513) | `wireframeClipboard` (+inject blockMutations) | no |
| `updateSelectedContainerArg` (568) | `wireframeEntryConfig` (structural selected-entry commit, same shape as updateSelectedConditions) | no |
| `isOutletEditing` (950) | `wireframeMutationEngine.isOutletEdited` (repoint consumers) | no |
| `canEdit` (227) | `wireframeEditMode` (session eligibility; reads siteSettings+currentUser) | no |
| `editableOutlets` (265) | `wireframeLayoutQuery` (outlet query; already injects blocks) | no |
| deselect: `#onCanvasMouseDown`/`#onCanvasMouseUp`/`isInsideAllowedScope` (156/177/1026) | `wireframeSelection` (self-install listeners, gate on session.active + isDestroyed) | no |
| drag lifecycle: `startDrag`/`startPaletteDrag`/`endDrag` (961/976/991) + `wireframe-dragging` body class | `wireframeDragSession` (+inject dragOverlay for the reset) | no |
| drop dispatch: `runDropDispatch` (1011) + `#dropDispatchRegistered` + the `registerDispatcher` wiring | **NEW `wireframe-drop-dispatch`** | **yes (2)** |
| publish/save/discard + session-draft layer + baseline + modals (~700 LOC) | **NEW `wireframe-publish`** | **yes (1)** |
| enter/exit/toggle/rediscover + rich-text-renderer swap + `wireframe-active` body class + one-way calls into publish/dragSession | **stays on `wireframe.js`** (the thin orchestrator) | n/a |

### Why drop dispatch is its OWN service (corrected — it is not session lifecycle)

`runDropDispatch` is the drop-action chokepoint: "resolve the previewed drop to its
owning service's method" (insertBlock/moveBlock → blockMutations; applyGridDrop/
moveBlockIntoCell/placeBlockInCell → gridManipulator). That is a distinct concern
from opening/closing a session — keeping it on the orchestrator just because the
orchestrator is top-of-DAG is the god-object reflex.

It can't fold into an existing service:
- dragSession / dragOverlay — the cycle (`blockMutations → dropAuthority →
  dragSession`) bars dragSession from injecting blockMutations, and the overlay's
  dependency-free `registerDispatcher` inversion exists to keep it clean.
- blockMutations / gridManipulator — the table routes BOTH block-mutation and grid
  drops, so neither single owner fits (it would dispatch the other's actions).

So a dedicated single-concern service is correct. It injects
blockMutations+gridManipulator+dragOverlay, holds the table, and **self-registers**
with the overlay in its constructor (boot-looked-up in the api-initializer, like
block-reveal/inline-edit/arg-edit). Extraction is transparent: nothing calls
`runDropDispatch` directly, so only the registration moves (out of `enter()`).

NOTE: a `wireframe-drop-dispatch` service was proposed and rejected as
over-engineering in reframe-C1 — but only because the kernel then existed as the
god-object to register the handler from. Dissolving the kernel removes that home, so
the dedicated service is now the right call, not over-engineering.

### Why drag lifecycle folds into dragSession (not a new service)

`startDrag`/`startPaletteDrag`/`endDrag` are drag-state transitions
(`beginBlock`/`beginPalette`/`clear` plus a defensive `overlay.clear()` and the
`wireframe-dragging` body class). dragSession already owns the drag state; it gains
a `wireframeDragOverlay` injection (acyclic — overlay is dependency-free) for the
reset. Drag sources (palette, block-toolbar handle, outline rows) inject
`wireframeDragSession`.

### Why deselect folds into selection (not a new service)

Deselect-on-outside-click is a selection concern. `wireframeSelection` self-installs
the document listeners in its constructor, gates on `session.active` +
`isDestroyed`/`isDestroying` (the C7 leaked-listener pattern), and calls its own
`selectBlock(null)` (firing the existing before/after seam). Acyclic
(selection→session). This is why no `wireframe-deselect` service is created.

### Why publish IS a new service (the second of two)

The publish/save/discard workflow orchestrates persistence + drafts + theme +
editEngine + modal + the in-session draft layer + the saved-draft baseline. No
existing single-purpose service is its home: `wireframeLiveLayout` is the HTTP
boundary, `wireframeDrafts` is server-draft CRUD, `wireframePublishTarget` is theme-target
resolution — folding a 700-LOC multi-service orchestration into any of them recreates
a god-object. The session-draft layer (`#materializeAllDrafts`/`#hydrateDrafts`/
`#persistedDraftLayouts`) is kept *with* the publish flow rather than split into
`wireframeDrafts`, because the baseline is read by both the layer and the publish
actions — splitting it scatters one piece of state across two services.

The earlier "not extractable / 88% entangled" call was wrong: the entanglement is
`#enterGeneration`/`#staleDraftQueue`/materialize/hydrate shared between enter/exit
and publish. Move that state INTO `wireframe-publish`; `enter()`/`exit()` call it
one-way (`publish.beginSession(themeId)` / `publish.endSession()`). One-way calls
are not entanglement.

## Execution: 3 cycles

**Cycle 1 — fold every stray into its existing home (no new services).** All the
same mechanical pattern (relocate member → repoint consumers → drop now-unused kernel
injection), batched into one green-able sweep:
- `notifyChromeInserted`/`flashBlock` → `wireframeBlockReveal` (overlooked facades)
- `cutSelected` → `wireframeClipboard` (+inject blockMutations)
- `updateSelectedContainerArg` → `wireframeEntryConfig`
- `isOutletEditing` → `wireframeMutationEngine.isOutletEdited`
- `canEdit` → `wireframeEditMode`; `editableOutlets` → `wireframeLayoutQuery`
- deselect (`#onCanvasMouseDown`/`#onCanvasMouseUp`/`isInsideAllowedScope`) →
  `wireframeSelection` (self-install, gate on session.active + isDestroyed — the C7
  leaked-listener pattern; this is the one non-trivial bit of the cycle)
- drag lifecycle (`startDrag`/`startPaletteDrag`/`endDrag` + `wireframe-dragging`
  body class) → `wireframeDragSession` (+inject dragOverlay)
  Leaves `runDropDispatch` + the publish cluster on the kernel.

**Cycle 2 — `wireframe-drop-dispatch` (new, small).** Move `runDropDispatch` + its
table + `#dropDispatchRegistered`; service self-registers with `wireframeDragOverlay`
in its ctor; boot-lookup in the api-initializer; delete the `registerDispatcher`
block from `enter()`. Transparent (no direct callers). Its own cycle only because
it's a new service with the self-register/boot-lookup wiring to get right.

**Cycle 3 — `wireframe-publish` (the elephant) + orchestrator cleanup.** Move the
publish/save/discard cluster + session-draft layer + baseline + reviewDrawer state +
conflict/stale modals. `enter()`→`publish.beginSession(themeId)`,
`exit()`→`publish.endSession()` (one-way). Consumers (publish-review-drawer, shell,
entry-pill, api-initializer) inject `wireframe-publish`. Then confirm `wireframe.js`
is pure session lifecycle (~100–150 LOC) + tighten its class JSDoc. Stands alone
because it carries the LOC bulk and needs its own adversarial review of the one-way
`enter/exit ↔ publish` boundary.

## End state: two new services (both genuine, home-less concerns)

`wireframe-drop-dispatch` (drop-action chokepoint) and `wireframe-publish` (publish/
draft lifecycle). Everything else folds into existing services. The orchestrator
keeps exactly one concern: editor session lifecycle.

## Risks & verification (per cycle)

- Cycle 4 is the structural-commit + draft-layer chokepoint — adversarial-review
  the one-way `enter/exit ↔ publish` boundary (no bidirectional reads; generation
  guard still invalidates stale hydration; conflict/stale modal flow intact).
- Deselect (cycle 3): re-apply the C7 leaked-listener guards (isDestroyed/isDestroying
  + remove on willDestroy); a synthetic-click test won't prove reachability — verify
  the gate logic, not just green.
- Each cycle: `bin/lint`, `pnpm ember-tsc` (plugin-clean), `bin/qunit --target
  discourse-wireframe` (baseline 687/2skip/0fail), grep no leftover facade refs
  (use the non-dot `\b(editor|wireframe)\.<member>\b` form + lookup()/defineProperty
  stub forms), and re-check test-stub registrations for any component the cycle
  repoints.
