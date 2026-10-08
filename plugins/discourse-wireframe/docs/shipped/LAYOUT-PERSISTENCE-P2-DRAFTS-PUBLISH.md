# P2 — Drafts / Publish / Reset (server) + remove the git redirect — SHIPPED

Part of the block-layout persistence redesign (see
`LAYOUT-PERSISTENCE-OVERVIEW.md`). Depended on P0/P1 (both shipped). This records
what actually landed; it deviates from the original plan in two structural ways
(the drafts store moved to the **plugin**, and concurrency is a `DistributedMutex`
lock, not a READ-COMMITTED assumption) — both are called out below.

## What shipped

The editor had one persistence verb (`saveAll`) that POSTed each edited outlet to
`Themes::SaveBlockLayout`, which redirected git themes to a `<name>-customizations`
child, baked + wrote the live `block_layout` ThemeField, and broadcast on
`/block-layouts/<theme_id>`. There was no draft store, no publish/reset
distinction, and no concurrency guard.

P2 split that into four verbs and added the safety:

- **Publish** → live ThemeField write (bake + broadcast), guarded by a
  stale-version **409**, serialized by a `DistributedMutex`.
- **Save draft** → private, never-live, per-user persistence; no live write, no
  broadcast.
- **Reset to default** → new `DELETE` removing the live field so the outlet falls
  back to the underlying (theme/code) layer.
- **Discard draft** → delete the caller's draft row.

The git child-redirect machinery is **gone**. Publishing a git theme's live field
is now blocked by `policy :theme_is_not_git` (→ 422) until P3 disables the button
and P4 adds Export/Duplicate.

## Core / plugin split (deviation from the plan)

The original plan put the drafts table, model, services, controller, and routes in
**core**. That was wrong: a draft is an edit-driven, editor-only concept and must
live in the plugin. The shipped layout is:

**Core (live ThemeField lifecycle only — no knowledge of drafts):**
- `app/services/themes/save_block_layout.rb` — publish. Redirect removed; gained
  `policy :theme_is_not_git`, an `expected_version_token` contract attr, and a
  `DistributedMutex` lock around the guard + write. Does **not** touch drafts.
- `app/services/themes/reset_block_layout.rb` (new) — delete the live field +
  broadcast removal. Does **not** touch drafts.
- `app/lib/themes/block_layout_version.rb` (new) — `token_for(value_baked)`.
- `app/controllers/admin/block_layouts_controller.rb` — `publish` + `destroy` only.
- `config/routes.rb` — `post`/`delete "block-layouts"` only.
- `lib/application_layout_preloader.rb` — `version_token` in each preload row.

**Plugin (`DiscourseWireframe` namespace — the drafts store):**
- `lib/discourse_wireframe/engine.rb` (new) — the Rails engine
  (`isolate_namespace`). `plugin.rb` defines `PLUGIN_NAME` then requires it.
- `config/routes.rb` (new) — draws the engine routes under
  `/admin/plugins/wireframe/block-layout-drafts` and **explicitly mounts** the
  engine (`Discourse::Application.routes.draw { mount ::DiscourseWireframe::Engine }`)
  — a plugin engine is not auto-mounted.
- `db/migrate/<ts>_create_block_layout_drafts.rb` (new) — `create_table
  :wireframe_block_layout_drafts` (the table name is future-proofed for the planned
  `discourse-wireframe` → `wireframe` rename).
- `app/models/discourse_wireframe/block_layout_draft.rb` (new).
- `app/services/discourse_wireframe/save_block_layout_draft.rb`,
  `discard_block_layout_draft.rb` (new).
- `app/controllers/discourse_wireframe/block_layout_drafts_controller.rb` (new) —
  `< ::Admin::AdminController`, `requires_plugin DiscourseWireframe::PLUGIN_NAME`.

Because `discourse-wireframe` is a **bundled** plugin, its
`wireframe_block_layout_drafts` table is included in core `db/structure.sql` (like
`chat_*`, `discourse_automation_*`, etc.) — `db:dump_structure` loads all bundled
plugins, and CI's `db:check_structure_dump` requires it there. `annotate:clean`
only covers core models, so the model's schema annotation was added by hand.

**Consequence:** core publish/reset no longer delete the caller's draft. The
editor client orchestrates draft cleanup after a successful publish/reset; the
actual wiring is deferred to P3 (the verbs exist on the persistence service now).

## The drafts table + model

Not the `Draft` model — its 40-char `draft_key`, 150 KB cap, and 180-day GC are
disqualifying.

```ruby
create_table :wireframe_block_layout_drafts do |t|
  t.integer :user_id, null: false
  t.integer :theme_id, null: false
  t.string :outlet, null: false
  t.text :data, null: false                 # {schema_version, layout} JSON, 1 MB cap
  t.string :base_version_token              # SHA-256 of the live value_baked at load; nullable
  t.timestamps
end
add_index :wireframe_block_layout_drafts, %i[user_id theme_id outlet], unique: true,
          name: "idx_wireframe_block_layout_drafts_unique"
add_index :wireframe_block_layout_drafts, %i[theme_id outlet]
```

Plain indexes (new table), no FK (Discourse convention), `data` is `text` to match
`ThemeField.value`. `DiscourseWireframe::BlockLayoutDraft` sets
`self.table_name`, `MAX_DATA_BYTES = 1024**2`, `belongs_to :user, :theme`, and
validates outlet format + `data` presence/length.

## Version token (the 409 guards the right store)

A per-user draft sequence can't detect another admin's live publish — the token
tracks the **ThemeField**. `Themes::BlockLayoutVersion.token_for(value_baked)` =
`value_baked.blank? ? "" : Digest::SHA256.hexdigest(value_baked)` (computed on read;
no new column; `""` when there's no live field yet). It's surfaced in the preload
rows and the MessageBus publish payload, so a tab that observes another admin's
publish refreshes its captured token (no self-inflicted 409).

## Concurrency = a DistributedMutex lock (deviation from the plan)

The plan claimed reading `value_baked` inside the transaction serializes concurrent
publishers under READ COMMITTED. **That is false** — the guard `SELECT` takes no row
lock, so two publishers can both read the stale token, both pass the guard, and the
second's `UPDATE` silently clobbers the first (no 409). The fix, folded in during
adversarial review, wraps the guard + write in the `Service::Base`
`lock(:theme_id, :outlet_name)` step (a `DistributedMutex`, the pattern at
`chat/add_users_to_channel.rb`). The second publisher waits, then
`guard_stale_publish` reads the first's committed token → 409.

```ruby
model :theme
policy :current_user_is_admin
policy :theme_is_not_git
lock(:theme_id, :outlet_name) do
  transaction do
    step :guard_stale_publish      # FIRST — reads value_baked under the lock
    step :upsert_field
    step :save_theme
    step :reload_field
    step :guard_against_bake_error
  end
end
step :publish_message_bus_update   # post-transaction; carries version_token
```

`guard_stale_publish` returns early when `expected_version_token` is nil (caller
opted out); otherwise it `pick`s the current `value_baked` (scoped by
`target_id: Theme.targets[:common]` + the `block_layout` type) and `fail!`s on a
token mismatch. The controller maps that step failure to **HTTP 409** and the
`theme_is_not_git` policy failure to **422**.

## Routes + controller (as shipped)

Core (in the `/customize` admin scope), replacing the old `post "block-layouts" =>
"block_layouts#create"`:

```ruby
post   "block-layouts" => "block_layouts#publish"
delete "block-layouts" => "block_layouts#destroy"
```

Plugin engine:

```ruby
post   "/block-layout-drafts" => "block_layout_drafts#create"
delete "/block-layout-drafts" => "block_layout_drafts#destroy"
```

Outlet + theme travel as params (avoids re-encoding `:` in outlet names). Core
`publish` adds `version_token` to the success render; `block_layout_drafts#create`
upserts via `find_or_initialize_by(user_id, theme_id, outlet)`.

**Endpoint shapes:**
- `POST /admin/customize/block-layouts` → `200 { success, theme_id, version_token }`;
  errors `400/404/422/**409**`.
- `DELETE /admin/customize/block-layouts` → idempotent `200 { success, theme_id }`.
- `POST /admin/plugins/wireframe/block-layout-drafts` → `200 { success }`; `400` on
  contract / 1 MB cap.
- `DELETE /admin/plugins/wireframe/block-layout-drafts` → idempotent `200 { success }`.

## Client (`wireframe-live-layout.js`) — the verb split

`saveAll` → four verbs (the toolbar's live "Save" calls `publish`; the draft/reset
verbs exist but their UI wiring lands in P3):

- **`publish(themeId)`** — POST core `block-layouts` with `expected_version_token`;
  on success collapse the session draft into the THEME layer keyed by the
  **requested** themeId (no server redirect to follow), capture the new token, clear
  `editedOutlets`. On **409** record a conflict and **keep** the outlet edited.
- **`saveDraft(themeId)`** — POST the plugin `block-layout-drafts`; no broadcast, no
  theme-layer collapse (SESSION_DRAFT stays resolved).
- **`resetToDefault(themeId, outlet)`** — DELETE core `block-layouts`; on success
  `_clearLayoutLayer` THEME locally.
- **`discardDraft(themeId, outlet)`** — DELETE the plugin `block-layout-drafts`.

Tokens are kept in a `${themeId}:${outlet}` map seeded once from the boot preload
(`PreloadStore.get("themeBlockLayouts")`) and advanced only by this tab's own
successful publishes — never from MessageBus — so a concurrent publish is detected
as a conflict, not silently adopted.

## Existing `-customizations` data

Pre-release ⇒ no migration. The redirect code and its specs were deleted. Stray
`-customizations` components from dev/testing still render as ordinary components
and can be removed by hand.

## Verification (all green)

- **RSpec service** — `save_block_layout_spec.rb` (git → `theme_is_not_git` policy
  failure; stale token → `guard_stale_publish` step failure; matching/nil token →
  success; `version_token` in the broadcast); `reset_block_layout_spec.rb` (deletes
  the live field, broadcasts removal). Plugin: `save_block_layout_draft_spec.rb` (row
  upserted; no ThemeField; no MessageBus), `discard_block_layout_draft_spec.rb`,
  `block_layout_draft_spec.rb` (outlet format, 1 MB cap, uniqueness).
- **RSpec request** — core `block_layouts_controller_spec.rb` (publish 200/409/422,
  reset DELETE); plugin `block_layout_drafts_controller_spec.rb` (draft POST/DELETE,
  non-admin/disabled → 404). 52 specs green.
- **JS** — `wireframe-live-layout-test.gjs` (9 tests): publish posts the token /
  collapses to THEME / 409 keeps the edit / refuses an empty resolved read; saveDraft
  hits the plugin endpoint and leaves THEME untouched; resetToDefault + discardDraft
  issue DELETEs.

## Carried forward

- **Client draft cleanup after publish/reset → P3.** Core no longer deletes drafts;
  the client must `discardDraft` on a successful publish so a stale draft can't
  shadow the now-live field next session. The verb exists; the call is wired in P3.
- **Conflict-resolution UX → P3.** A 409 currently surfaces via the existing error
  banner and keeps the outlet edited.
- **Git Export/Duplicate → P4.** Publishing a git theme is 422 in the interim.
