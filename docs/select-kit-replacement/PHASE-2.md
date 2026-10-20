# Phase 2 — Rollout foundations (wave 0)

**Goal:** everything the rollout depends on is in place, with no user-visible change: the flag,
the switch plumbing, the deprecations, the bridge contract, and test infrastructure that drives
either implementation.

See [`ROLLOUT.md`](ROLLOUT.md), *Rollout architecture* and *Waves*. Re-sequenced 2026-10-14: the
facade and codemod plan this phase used to carry is superseded.

## Tasks

- ◐ **Modal Enter bug** (`28f9c5153fb`): `DModal` submitted on Enter inside a `DSelect` because its
  exemption covered `.select-kit` but not `role="combobox"`. Fixed here with five `DSelect`
  tests, each failing before the fix; two weaker fixes were planted and caught. The standalone
  PR on `main`, with ARIA-markup tests (no `DSelect` there), is open as #44869.
- ☑ **Flag** `enable_new_select_controls`: conceptual, impact `other,all_members`, read live from
  `siteSettings` like `enable_new_reordering_controls`. No rollout service and no runtime family
  list; a family joins when its converted call sites merge. `body_class` waits for the first family
  that needs CSS.
- ☑ **Class root:** flipped `.d-combobox` to `.d-select` (`0b437b5d674`).
- ☑ **`modifyClass` deprecation** (`select-kit-modify-class-deprecation.ts`): fires after the
  patch is applied, for the exact class of a module in `MIGRATED_SELECT_KIT_MODULES` while the flag
  is on; throws in development, `notify-admin` in production; one admin notice per id. The set is
  empty until wave 1. **When a family joins:** add its module paths to the set; any bundled-plugin
  test that turns the flag on and patches that family then fails (QUnit raise-on-deprecation,
  system specs' `EMBER_RAISE_ON_DEPRECATION`), which is intended; add a boot test with a real plugin
  patch.
- **Third-party notice:** moved to wave 1 ([Phase 3](PHASE-3.md)) as a render-time notice; the
  import-time design was dropped (see `ROLLOUT.md`).
- ☑ **Bridge contract:** fixtures mirroring both known callers' generic reads; `triggerSearch`, an
  `isLoading` that drives the pending state, and facade `content` and `value`. The per-callback
  opt-out moves to wave 1 with the discourse-ai port; per-use telemetry is dropped, since
  reporting once per select per plugin already measures use. Row `classNames` is not bridged:
  callers move to `spec.row` classes when they are ported.
- ☑ **Patch replacement matrix** ([`PATCH-MATRIX.md`](PATCH-MATRIX.md)), from a verified audit
  (see `ROLLOUT.md`, blast radius). Its per-repo list names customer repos, so it is kept outside
  the repository.
- ☑ **Customization API:** one `select-customizations` transformer targeting `@kind` or
  `@identifier` replaces the four per-point transformers (`2a8637024a4`).
- ☑ **Presentation options:** `spec.options` overrides a select's caret icon, icon-only trigger,
  placeholders, label, none-row label, disabled state and more, which only call sites could set
  before (`dc9d88ce4b5`).
- ☑ **Row titles:** `spec.row` sets a row's `title`; an item's own `title` is never a tooltip
  (`dc9d88ce4b5`).
- ☑ **Recipe options:** recipes declare overridable values with `@kindOptions` (`aef9c15d75c`).
- ☑ **Test infrastructure:** tests branch with the flag instead of one test driving both
  implementations (see `ROLLOUT.md`, Verification). DSelect has stable `data-value`/`data-name`
  hooks and a `data-select-id` panel link (`1acddc9ddf5`); QUnit gets `dSelect()` and
  `assert.dSelect()`, and the form-kit helpers drive a DSelect field (`444fad40435`); system specs
  get `UiKit::DSelect.at` with value-based actions and matchers, and the FormKit page object drives
  a DSelect field (`458cd7f3783`); `with_select_controls(enabled)` pins the flag for an example
  group.
- ☑ **Prep that also works with select-kit:** writing a value back without `onChange` emits
  `discourse.select-kit.implicit-mutation`, which core and bundled plugin tests raise on
  (`a29213b026c`); explicit `onChange` at the 19 core two-way sites and the wizard (`db1667d9232`)
  and the 10 bundled plugin sites (`c9e8b5cb55c`); `selectControl` replaces the `.select-kit-header`
  queries (`07e7bece2e9`).
- ☑ **Guideline:** DMenu vs DSelect in the ui-kit guide (`e123d0c4fe6`).

## Exit criteria

- Flag and deprecations land with tests; no consumer has joined yet.
- The DSelect test helpers pass against every variant, and the flag pin holds whether or not the
  change is promoted.
