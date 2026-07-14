# Phase 0 — Foundations

**Goal:** land the shared machinery + one real component so later phases are pure
composition. Harden the primitives, build the headless engine + `DSelect` (single mode)
beside the existing `DMultiSelect`, wire the extension bridge, and author it all in
TypeScript.

See RFC: *Phase 0*, *Chosen approach*, *Extension model*, *Decision 6 (TypeScript)*.

## Tasks

- ☑ **0a** — Worktree off `main`; port `d-roving-focus` + `d-skeleton` from the editor branch; add the Worktrees rule to `CLAUDE.local.md`; save the RFC doc.
- ☑ **0b** — Harden `dRovingFocus` `active` (combobox) mode for text inputs + keyboard unit tests.
- ☑ **0c** — Improve `DAsyncContent`: accept a synchronous `@asyncData` return; thread an `AbortSignal` (abort on supersede/teardown). Backward-compatible.
- ☑ **0d** — `SelectEngine` (headless, **controlled** via a `getValue` thunk) feeding `DAsyncContent`; `buildItems` / `resolveSelection` / `reload`; frozen projections only.
- ☑ **0e** — Register `select-content` (value) + `select-on-change` (behavior) transformers; implement the `modifySelectKit` compat bridge (3-phase order, per-engine `EmberObject` facade, identifier fan-out, onChange items, suppression, per-use deprecation).
- ☑ **0f** — `DSelect` single + multi + simple/static modes on the engine + internal parts; a11y (combobox/listbox, roving, `a11y.announce`); integration tests green.
- ☑ **0g** — Migrate `DIconGridPicker` announcements to the `a11y` service.
- ☑ **TS conversion** (Decision 6) — rebase onto `origin/main` (#41478), convert the family + primitives to `.ts`/`.gts`, strict-grade.
  - ☑ Rebase onto latest `origin/main` (clean).
  - ☑ Convert `select-engine.ts`, `d-select.gts`, `select-item.gts`, `modify-select-kit-bridge.ts`, `d-async-content.gts`, `d-roving-focus.ts`, `d-skeleton.gts`.
  - ☑ `d-icon-grid-picker/content.gjs` stays JS (decided).
  - ☑ `pnpm lint:types` green (0 errors) + `bin/lint` clean.
  - ☑ qunit modules green after conversion — 96/96 (engine 20, bridge 11, DSelect
    single 9 / multi 3 / bridge 2, DAsyncContent 24, dRovingFocus 17, DSkeleton 10).
  - ☑ Committed + draft PR #41534 open, shipping as TS.

## Exit criteria

- The engine + `DSelect` (single/multi/simple) pass integration + a11y tests.
- The `modifySelectKit` bridge passes its fidelity tests.
- The whole family + primitives are TypeScript, `pnpm lint:types` clean, `bin/lint` clean.
- Draft PR #41534 ships and builds as TS.

## Notes

- Shipped as draft PR #41534.
- `dRovingFocus` / `DSkeleton` land on `main` via this branch; the editor branch later
  drops its copies and adopts these (now-TS) versions — coordinate that hand-off.
