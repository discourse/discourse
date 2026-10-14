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
- ☐ **`modifyClass` deprecation:** detect select-kit classes after resolution, joined families
  only (the list lives here), per source and target; throw in development, `notify-admin` in
  production; admin notices keyed by id and source.
- ☐ **Third-party deprecation** at import time, under `discourse.select-kit-rollout.*`.
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
