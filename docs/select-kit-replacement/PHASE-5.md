# Phase 5 — Ban from core/bundled + finalize deprecation

**Goal:** core and bundled plugins are fully off select-kit and lint-banned from
reaching for it again; select-kit stays (deprecated) for third parties.

See RFC: *Migration strategy*, *Roadmap › Phase 5*. (Maps to dev topic P11.)

## Tasks

- ☐ Port the ~19 bundled plugins that **subclass** select-kit bases off them (the last
  in-repo consumers — e.g. chat channel chooser, discourse-assign, discourse-activity-pub,
  discourse-workflows, discourse-adplugin).
- ☐ Add the **ban lint rule**: forbid `select-kit/*` imports + the old angle-bracket tags
  in core `app/`, `admin/`, and bundled `plugins/`.
- ☐ Publish the codemod + a third-party migration guide (optional adoption; deprecation
  warnings + telemetry nudge).

## Exit criteria (end state)

- Core + bundled fully migrated and lint-banned from select-kit.
- **No deletion**: select-kit, its SCSS, `compat-modules`, the `modifySelectKit` bridge,
  and `DNativeSelect` remain (deprecated) for out-of-repo consumers.
