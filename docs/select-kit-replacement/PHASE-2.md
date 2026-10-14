# Phase 2 — Rollout foundations (wave 0)

**Goal:** everything the rollout depends on is in place, with no user-visible change: the flag,
the switch plumbing, the deprecations, the bridge contract, and test infrastructure that drives
either implementation.

See [`ROLLOUT.md`](ROLLOUT.md), *Rollout architecture* and *Waves*. Re-sequenced 2026-10-14: the
facade and codemod plan this phase used to carry is superseded.

## Tasks

- ☐ **Modal Enter bug** (test-first): `DModal` submits on Enter inside a `DSelect` because its
  exemption covers `.select-kit` but not `role="combobox"`.
- ☐ **Flag** `enable_new_select_controls` (experimental, `body_class: true`) and the boot-snapshot
  service, with a test helper and the list of joined families.
- ☐ **Class root:** flip `.d-combobox` to `.d-select`.
- ☐ **`modifyClass` deprecation:** detect select-kit classes after resolution, joined families only,
  per source and target; throw in development, `notify-admin` in production; admin notices keyed
  by id and source.
- ☐ **Third-party deprecation** at import time, under `discourse.select-kit-rollout.*`.
- ☐ **Bridge contract:** fixtures mirroring real `modifySelectKit` callers; add `triggerSearch`, a
  working `isLoading`, row `classNames`, per-callback suppression, per-use telemetry.
- ☐ **Patch replacement matrix** for the known `modifyClass` customizations, with the supported
  APIs they move to.
- ☐ **Test infrastructure** for both implementations: `SelectKit` page object, `selectKit()`
  helper, `form-kit-helper.js`, and callers that pass `.select-kit` roots. Specs pin the flag.
- ☐ **Prep that also works with select-kit:** explicit `onChange` at the two-way sites, stable hooks
  in place of `.select-kit` DOM queries, the wizard's `onChange`.
- ☐ **Guideline:** DMenu vs DSelect in the ui-kit guide.

## Exit criteria

- Flag, snapshot service and deprecations land with tests; no consumer has joined yet.
- The test infrastructure passes against a family branched in both modes.
