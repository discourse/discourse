# Phase 2 — Rollout foundations (wave 0)

**Goal:** everything the rollout depends on is in place, with no user-visible change: the flag,
the switch plumbing, the deprecations, the bridge contract, and test infrastructure that drives
either implementation.

See [`ROLLOUT.md`](ROLLOUT.md), *Rollout architecture* and *Waves*. Re-sequenced 2026-10-14: the
facade and codemod plan this phase used to carry is superseded.

## Tasks

- ◐ **Modal Enter bug** (`28f9c5153fb`): `DModal` submitted on Enter inside a `DSelect` because its
  exemption covered `.select-kit` but not `role="combobox"`. Fixed here with five `DSelect`
  tests, each failing before the fix; two weaker fixes were planted and caught. Still to do: a
  standalone PR on `main` with ARIA-markup tests (no `DSelect` there).
- ☑ **Flag** `enable_new_select_controls`: conceptual, impact `other,all_members`, read live from
  `siteSettings` like `enable_new_reordering_controls`. No rollout service and no runtime family
  list; a family joins when its converted call sites merge. `body_class` waits for the first family
  that needs CSS.
- ☐ **Class root:** flip `.d-combobox` to `.d-select`.
- ☑ **`modifyClass` deprecation** (`select-kit-modify-class-deprecation.ts`): fires after the
  patch is applied, for the exact class of a module in `MIGRATED_SELECT_KIT_MODULES` while the flag
  is on; throws in development, `notify-admin` in production; one admin notice per id. The set is
  empty until wave 1. **When a family joins:** add its module paths to the set; any bundled-plugin
  test that turns the flag on and patches that family then fails (QUnit raise-on-deprecation,
  system specs' `EMBER_RAISE_ON_DEPRECATION`), which is intended; add a boot test with a real plugin
  patch.
- **Third-party notice:** moved to wave 1 ([Phase 3](PHASE-3.md)) as a render-time notice; the
  import-time design was dropped (see `ROLLOUT.md`).
- ☐ **Bridge contract:** fixtures mirroring real `modifySelectKit` callers; add `triggerSearch`, a
  working `isLoading`, row `classNames`, per-callback suppression, per-use telemetry.
- ☐ **Patch replacement matrix** for the known `modifyClass` customizations, with the supported
  APIs they move to.
- ☐ **Test infrastructure** for both implementations: `SelectKit` page object, `selectKit()`
  helper, `form-kit-helper.js`, and callers that pass `.select-kit` roots. Specs pin the flag.
- ☐ **Prep that also works with select-kit:** explicit `onChange` at the two-way sites, stable hooks
  in place of `.select-kit` DOM queries, the wizard's `onChange`.
- ☑ **Guideline:** DMenu vs DSelect in the ui-kit guide (`e123d0c4fe6`).

## Exit criteria

- Flag and deprecations land with tests; no consumer has joined yet.
- The test infrastructure passes against a family branched in both modes.
