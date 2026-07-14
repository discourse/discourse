# P3 — Editor UX: per-outlet states, verbs, modals — SHIPPED

Part of the block-layout persistence redesign (see `LAYOUT-PERSISTENCE-OVERVIEW.md`).
Depended on P0–P2 (shipped). This records what actually landed. Shipped as one phase;
three product decisions were taken up front (one phase; enrich the core 409 + full conflict
modal; per-outlet verbs in a new inspector section), and two items were deliberately scoped
out (see "Deferred").

## What shipped

The editor was session-theme-scoped (one global `activeThemeId`, every outlet drafted alike,
Save POSTed everything to that one theme, "Reset" was an in-memory discard-all, 409s were a
raw string). P3 makes the **outlet** the unit of editing:

- A derived per-outlet **state** — LOCKED / DEFAULT / PUBLISHED — plus an orthogonal EDITING
  signal, shown as a badge in the inspector and on the outlet-root chrome.
- **LOCKED outlets are read-only**: excluded from drafting, no chrome toolbar, clicks swallowed.
- **Per-outlet owner targeting**: each region publishes to the theme that owns it (P1 stack-rank;
  A-P4 §0 later flipped this from min to MAX — the most-derived theme/component owns), not one
  session theme.
- **Drafts hydrate on enter** from the per-user store, with a **stale-draft prompt** when the
  live layout moved on since the draft was saved.
- **Verb split**: per-outlet Save draft / Publish / Reset to default / Discard in the inspector;
  the global toolbar keeps Save and a relabeled "Discard all changes".
- **Structured 409 conflict prompt** (Overwrite / Cancel) replacing the raw-string banner.

## Core touchpoints (plugin-agnostic, minimal)

P3 is mostly plugin work, but it needed two small core additions — both pure
layer/version mechanism, no editor vocabulary:

- `frontend/discourse/app/blocks/block-outlet.gjs` — new production-safe
  `_getResolvedLayoutMeta(name, { ignoreSessionDraft })` returning the winning layer's
  provenance (`source`/`sourceId`/`overridable`/`themeStackIndex`); `resolveLayoutRecord` gained
  an `ignoreSessionDraft` option (default false, all existing callers unchanged). Reactive via
  the same single `trackedMap` read as `_getResolvedLayout`; NOT DEBUG-gated.
  **Design note:** this stateless, draft-ignoring accessor replaced the originally-planned
  `#persistedSource` snapshot map (adversarial review: a snapshot goes stale on a mid-session
  MessageBus publish and can't carry owner identity — the draft entry has no `themeId`).
- `frontend/discourse/app/services/blocks.js` — `resolvedLayoutMeta(name, opts)` wrapper.
- `app/services/themes/save_block_layout.rb` + `app/controllers/admin/block_layouts_controller.rb`
  — the stale-publish 409 now carries `current_version` (live token) + `published_at` (the
  field's `updated_at`), so the client can Overwrite against the current version. The guard
  `pick`s `(:value_baked, :updated_at)` and stashes both on the service context.

## Plugin pieces

- `services/wireframe.js` — `OUTLET_STATE`; `outletState` / `outletOwner` / `isOutletEditing` /
  `isOutletEditable` (plain reactive methods, never `@cached`); public `defaultThemeId`; LOCKED
  excluded from `#materializeAllDrafts` + `ensureDraft`; async `#hydrateDrafts` kicked from a
  still-synchronous `enter()` via `schedule("afterRender", …)`, generation-guarded
  (`#enterGeneration` bumped on enter/exit) and pristine-guarded (skips outlets touched since
  enter); the verb split (`discardOutlet` / `discardAll` / `resetToDefault`, refactored onto
  `#rollbackOutletInMemory` + `#editedOutletNames`); publish orchestration
  (`publishEditedOutlets` / `publishOutlet` / `#processPublishResult` / `#resolvePublishConflict`)
  shared by the toolbar Save and the per-outlet Publish; `saveDraftOutlet`.
- `services/wireframe-drafts.js` (new) — owns all draft I/O: `fetchDrafts` (error-swallowing,
  drops unparseable rows), `saveDraftOutlet`, `deleteDraft` (idempotent, swallows transport
  errors). The draft write/delete verbs moved here out of `wireframe-live-layout.js`.
- `services/wireframe-live-layout.js` — per-owner publish loop (keeps the passed `themeId` as the
  owner *fallback*); Git-owned outlets are **skipped** (never written, draft preserved — handed to
  P4); `overwriteOutlet`; `tokenFor` made public (the drafts service stamps a draft's baseline
  with it); post-publish `deleteDraft` cleanup (the P2-deferred wiring).
- Plugin engine GET `block_layout_drafts#index` (new — P2 built only create/destroy) returning the
  current user's own draft rows, optionally theme-scoped.
- Components: `components/editor/inspector-outlet-section.gjs` (state badge + state-gated verbs);
  `stale-draft-modal.gjs` + `conflict-modal.gjs` (DModal, template-only);
  `block-chrome.gjs` (outlet-root state badge + EDITING pill; LOCKED read-only suppression —
  `--read-only` class, no toolbar, click swallowed); `shell.gjs` (toolbar relabel + delegates Save
  to the service); `inspector-panel.gjs` (renders the outlet section for an outlet root).
- `config/locales/client.en.yml` — `wireframe.outlet.*`, `wireframe.stale_draft.*`,
  `wireframe.conflict.*`, `wireframe.chrome.discard_all`.

## Deferred (not in this phase)

- **ConflictModal "View theirs" (read-only preview of the published version).** A faithful preview
  needs a draft-stash/preview-mode toggle — a sizable sub-feature. P3 ships Overwrite (re-POST
  against the server's current version) / Cancel (keep editing); both preserve the edit. The
  preview is a P3 follow-up.
- (The on-canvas LOCKED badge + chrome read-only suppression was originally going to be deferred
  too, but was built in this phase.)

## Verification (all green)

- **qunit** — full plugin suite 439/439; core `resolved-layout accessors` 6/6 (incl.
  `_getResolvedLayoutMeta` + `ignoreSessionDraft`). New: `wireframe-drafts-test`,
  `wireframe-outlet-state-test`; rewritten `wireframe-live-layout-test` for the verb split +
  per-owner publish + 409 metadata + `overwriteOutlet`; the inspector-outlet stub gained the new
  surface. A shared `setupBlockLayoutDraftsStub(hooks)` helper stubs the drafts GET in the 8
  `enter()`-using test files (hydration fetches on enter).
- **ember-tsc** — clean.
- **rspec** — plugin `block_layout_drafts_controller_spec` (`#index` scoping/auth); core
  `block_layouts_controller_spec` (409 body carries `current_version` + `published_at`);
  `save_block_layout_spec`.
- **lint + `/discourse-code-conventions`** — clean (3 findings applied: `#clearOutletEditState`
  privatized; a `#themeMeta` doc-placement fix; `resetAll` doc shortened; dead bulk `saveDraft`
  removed).

## Carried forward

- **A-P4** — git Export/Duplicate (publishing a git-owned outlet is disabled in the interim;
  the draft is preserved).
- **ConflictModal "View theirs"** preview (above).
