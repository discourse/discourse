# Phase 5 — Plugin subclasses, promotion and cleanup (wave 5)

**Goal:** the last in-repo consumers join, the flag is promoted to `permanent`, and core and
bundled plugins are cleaned up and lint-banned from select-kit, which stays deprecated for third
parties.

See [`ROLLOUT.md`](ROLLOUT.md), *Waves* and *Promotion*. Re-sequenced 2026-10-14.

## Tasks

- ☐ **Wave 5:** port the 20 bundled plugin subclasses (e.g. chat channel chooser,
  discourse-assign, discourse-workflows, discourse-adplugin, discourse-subscriptions), the
  remaining plugin SCSS, and the remaining customer ports.
- ☐ **Beta**, once every gate in `ROLLOUT.md` holds. Beta is the production rollout.
- ☐ **Stable, then permanent** with group targeting cleared.
- ☐ **Cleanup:** delete the `else` branches (`TODO (select-kit-replacement-cleanup)`) and
  legacy-only code in core and bundled plugins.
- ☐ **Ban lint rule** for `select-kit/*` imports and the old tags in core and bundled plugins, with
  named exceptions (the bridge's `select-kit/lib/plugin-api` import, compat-modules, retained
  styles).
- ☐ **Third-party migration guide.**

## Exit criteria (end state)

- Core and bundled plugins are fully migrated and lint-banned from select-kit.
- **No deletion:** select-kit, its SCSS, `compat-modules`, the `modifySelectKit` bridge and
  `DNativeSelect` remain, deprecated, for out-of-repo consumers.
