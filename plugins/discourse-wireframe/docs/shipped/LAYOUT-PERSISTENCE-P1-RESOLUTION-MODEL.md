# SHIPPED — P1: resolution model, `overridable` flag & provenance

> **Status: shipped & verified green.** Second phase of the block-layout persistence redesign
> (see `COMING-NEXT-LAYOUT-PERSISTENCE-OVERVIEW.md`). Depends on P0 (shipped). This is the core
> render chokepoint the i18n work (B), P3, and P4 build on.

## Problem (as-was)

`resolveLayoutRecord` resolved `SESSION_DRAFT → THEME[last in array] → CODE_DEFAULT`. Three issues:
`api.renderBlocks` could only write the lowest-priority code slot and **threw on a 2nd
registration** (a plugin/theme couldn't ship an authoritative layout); "last theme in the array
wins" was the wrong owner (append order + MessageBus re-hydration; the parent may ship nothing),
diverging from Discourse's parent-wins field convention (`theme.rb:638`); and there was no
provenance, so consumers couldn't badge/own outlets.

## What landed

> **Superseded by A-P4 (§0):** the theme-owner tie-break below was **reversed** from MIN to MAX
> `themeStackIndex` — the most-derived theme (a component) now OVERRIDES the parent, instead of the
> parent winning. The determinism guarantee (winner keyed on the server-authoritative `stack_index`,
> not array order) is unchanged; only the direction flipped. Read "MIN"/"most-ancestral"/"parent-wins"
> below as the historical P1 behaviour. See the A-P4 shipped doc for the current rule.

**Core (`frontend/discourse`):**
- `app/blocks/block-outlet.gjs` — rewrote `resolveLayoutRecord` to the precedence **locked code →
  session draft → owner theme (MIN `themeStackIndex`) → overridable code seed**. Added
  `LAYOUT_SOURCE` and `CODE_LAYOUT_OVERRIDABLE_BY_DEFAULT` exports. Split the single CODE record
  slot into internal `code-locked` / `code-overridable` keys (public `LAYOUT_LAYERS.CODE_DEFAULT`
  name unchanged; `_setLayoutLayer` routes by the resolved `overridable` flag; `_clearLayoutLayer`
  for CODE_DEFAULT clears **both** slots). `createLayerEntry` now stamps provenance
  (`source`/`sourceId`/`overridable`/`themeStackIndex`) as plain own-properties and **keeps
  `themeId`** (the i18n seam). `_renderBlocks` replaced the 2nd-registration throw with a collision
  matrix: seed+seed and locked+locked throw (naming both `sourceId`s); locked+seed coexist (lock
  wins, seed is the fallback).
- `app/lib/plugin-api.gjs` — `renderBlocks(outlet, blocks, { overridable, sourceId })`, source-agnostic.

**Server (`lib`):**
- `application_layout_preloader.rb` — new `themeBlockLayoutMeta` preload, keyed by theme id, each
  carrying `{ name, is_git, component, stack_index }` (`stack_index` = position in
  `Theme.transform_ids`). A **new** key, not an extension of `activatedThemes` (which is consumed
  elsewhere).

**Plugin (`plugins/discourse-wireframe`):**
- `load-theme-block-layouts.js` — reads `stack_index` from the new preload and passes
  `themeStackIndex` to `setLayoutLayer` in both hydrate and the MessageBus path; ownership no
  longer depends on array order. `wireframe.js` — one precedence comment tightened.

## Decisions / deviations from the original plan

- **Stack rank is server-authoritative.** The original doc inferred rank client-side from preload
  row order and deferred a server-emitted `stack_index` to a follow-up. Since P1 added the
  per-theme metadata preload anyway, `stack_index` is emitted there and read authoritatively by
  both hydrate and MessageBus — eliminating the client-side inference and the
  "MessageBus-update-steals-ownership" edge. (Folds the overview's deferred follow-up into P1.)
- **Clearing `CODE_DEFAULT` clears BOTH code slots** (resolving a doc inconsistency; matches the
  old single-slot semantics). Consequence: a coexisting seed does **not** survive a public clear of
  a lock. Flagged as the open decision; left as-is for v1 (granular clear would add API surface).
- The metadata preload key is `themeBlockLayoutMeta`.

## Verification (all green)

- **RSpec** — `application_layout_preloader_spec.rb`: the meta map carries `name`/`component`/
  `is_git`/`stack_index` per theme in `transform_ids` order, and marks a remote (git) theme. **8/8.**
- **qunit core** — `Unit | Lib | block-outlet` (flipped multi-theme/duplicate tests to min-rank +
  the new locked/seed/coexist/collision/provenance/order-independence/keeps-rank cases): **97/97**;
  `Integration | Blocks | BlockOutlet` incl. a post-paint autotracking re-render test: **82/82**;
  `Integration | Blocks | BlockLayoutWrapper`: **14/14**.
- **qunit plugin** — `load-theme-block-layouts` (owner = most-ancestral; "a live update for a
  lower-ranked theme doesn't steal ownership", using the canonical `publishToMessageBus` helper):
  **7/7**; `service:wireframe` editor regression: **130/130**.
- `bin/lint --fix` clean; `pnpm ember-tsc` introduces no new errors (pre-existing glint baseline
  only); `/discourse-code-conventions` clean (one finding fixed: a core comment said "editor
  tooling" → "consumers").

## Notes for the next phase

- **Next: P2** (drafts / publish / reset server + remove the git redirect). It builds on this
  resolution model and provenance.
- The i18n seam holds: `entry.themeId` is still stamped on THEME entries, and the new provenance
  fields (`source`/`sourceId`) don't collide with the i18n `__themeId` context arg.
- The per-theme metadata preload (`themeBlockLayoutMeta`, with `is_git` + owner name) is the single
  source of truth P3 (page-scoped targeting) and P4 (git-awareness) consume.
