# SHIPPED — P0: production read/save data-loss fix

> **Status: shipped & verified green.** First phase of the block-layout persistence redesign
> (see `COMING-NEXT-LAYOUT-PERSISTENCE-OVERVIEW.md`). This was the precondition for P1–P4 and a
> live data-loss fix. Shipped essentially as planned; deviations noted below.

## Problem (as-was)

The block editor read resolved layout state through accessors compiled out in production: both
`_getOutletLayouts()` and `_getRawOutletLayouts()` (`block-outlet.gjs`) `return new Map()` when
`!DEBUG`. So in a real build the editor's `readResolvedLayout` returned `null` for every outlet,
and `_saveOutlet` POSTed `serializeLayoutForSave(null ?? [])` → `layout: []`, **wiping the
persisted layout.** The real resolver `resolveLayoutRecord` was never DEBUG-gated and already
autotracks its `trackedMap` reads — the fix was to expose non-DEBUG reactive wrappers around it.

## What landed

**Core (`frontend/discourse`):**
- `app/blocks/block-outlet.gjs` — two new non-DEBUG exports after `_getValidatedLayout`:
  - `_getResolvedLayout(outletName)` → `resolveLayoutRecord(outletName)?.layout ?? null`.
  - `_getResolvedLayouts()` → the un-gated form of `_getOutletLayouts`'s old DEBUG-branch body
    (fresh `Map`, iterate `outletLayouts.keys()`, resolve each). Returns `LayerEntry` objects.
  - The DEBUG-only `_getOutletLayouts` / `_getRawOutletLayouts` were left untouched (test infra).
- `app/services/blocks.js` — public passthroughs `resolvedLayout(outletName)` / `resolvedLayouts()`
  mirroring the existing `hasLayout()`.

**Plugin (`plugins/discourse-wireframe`):**
- `services/wireframe.js` — `readResolvedLayout` now returns `_getResolvedLayout(outletName)`
  (transitively fixing the ~50 callers through it: 31 here, 15 in `grid-manipulator.js`, 4 in
  `inline-edit-state.js`); the 6 direct `_getOutletLayouts()` calls now use `_getResolvedLayouts()`;
  import updated; two stale doc-comments referencing `_getOutletLayouts()` updated.
- `services/wireframe-live-layout.js` — permanent save backstop in `_saveOutlet`: throws when
  `layout.length === 0 && resolvedLayout == null` (read failed), so the outlet routes into
  `saveAll`'s catch, is reported as an error, and is **not** cleared from `editedOutlets` — the
  draft is preserved instead of silently lost. A deliberate delete-all resolves to a real `[]`
  (not `null`), so it still saves.
- `lib/walk-layout.js` — now reads `blocksService.resolvedLayouts()` (the passthrough; the helper
  already receives `blocksService`); the direct `_getOutletLayouts` import was removed. This makes
  the outline work in production.
- `components/editor/outline-panel.gjs` — dropped the stale "Phase 1 limitation / Phase 3 replaces
  the data source" comment.

## Deviations from the plan

- **walk-layout** uses the `blocksService.resolvedLayouts()` passthrough rather than a direct core
  import (the helper already has `blocksService` in hand; matches the doc's passthrough guidance).
- **New core test** placed at `frontend/discourse/tests/unit/lib/resolved-layout-test.js` (plain
  `.js`, beside the existing `block-outlet-test.js`) rather than the planned
  `tests/unit/blocks/resolved-layout-test.gjs` — P0's checks are pure unit assertions with no
  rendering, so no `<template>`/`.gjs` is needed. The render/autotracking test belongs to P1.

## Verification (all green)

- **Core unit** — `frontend/discourse/tests/unit/lib/resolved-layout-test.js` (4 tests): registered
  outlet resolves to a non-empty array (not `null`); unregistered outlet → `null`;
  `_getResolvedLayouts().get(outlet).layout` is the same resolved array with `size > 0`; a
  no-DEBUG-gate regression guard. **4/4 pass.**
- **Plugin unit** — extended `wireframe-live-layout-test.gjs`: the POSTed layout is asserted
  non-empty, plus a new "refuses to POST and keeps the draft when the resolved read fails" test
  (stubs `readResolvedLayout → null`; asserts an error is recorded, `editedOutlets` retained, no
  POST issued). The full `service:wireframe` unit suite (move/drop/paste/undo/insert/delete — every
  transitive `readResolvedLayout` caller) is **130/130 green**, persistence **5/5 green**.
- `bin/lint --fix` clean on all 8 changed files.

## Notes for the next phase

- `bin/qunit` gotcha hit while verifying: the **file-path** filter matched nothing
  (`--standalone <path>`); use `--filter "<module-name-substring>"` instead, and `--target
  discourse-wireframe` to include the plugin's tests (the core standalone build excludes plugin
  tests). The core build cache key (`assemble_ember_build.rb` `JS_SOURCE_PATHS`) only tracks
  `frontend/**`, so plugin-only edits don't bust it — pass `--target` to force the plugin build.
- A `git mv` followed by rewriting the moved file leaves the index inconsistent and breaks
  `assemble_ember_build.rb`'s git tree-hash; `git add` the moved file to reconcile before building.
- **Next: P1** (resolution model + `overridable` flag + provenance). P1 rewrites
  `resolveLayoutRecord` (currently still "last theme in stack wins") and must preserve the
  `entry.themeId` stamp for the i18n seam.
