# P4 — Git-theme flow: Export / Duplicate / Customization component — SHIPPED

Part of the block-layout persistence redesign (see `LAYOUT-PERSISTENCE-OVERVIEW.md`). Depended on
P0–P3 (shipped). This records what actually landed. The original doc was reshaped substantially
during planning (grounding + 2 design agents + a 2-lens adversarial review + several user decisions);
the deviations are called out below.

## What shipped

A Git-managed theme's block-layout outlets are read-only in the editor (Publish disabled — P3). P4
adds three explicit escape hatches, surfaced per-outlet in the inspector when the outlet's owner is
Git-managed:

- **Create customization component** (primary) — creates/reuses a local `<name>-customizations`
  component, links it as a child of the Git theme, and overlays the current drafts. Because of the
  ownership flip (§0), the component overrides the Git parent for those outlets and is itself
  non-Git, so **Publish enables** for them after a reload. The Git theme stays untouched and keeps
  receiving upstream updates.
- **Export** — downloads the outlet's layout as `block_layouts/<outlet>.json` to commit upstream.
- **Duplicate** — full clone of the theme into a new editable (non-Git) theme with drafts overlaid,
  for "I want my own fork." A theme can forbid this via a modifier (Horizon).

## §0 — Ownership reversed: a component now overrides its parent (P1-resolver revision)

`resolveLayoutRecord` (`frontend/discourse/app/blocks/block-outlet.gjs`) step 3 was flipped from
**MIN** to **MAX** `themeStackIndex`: among the theme-layer entries for an outlet, the most-derived
theme (`Theme.transform_ids` orders parent-first, components after) now wins, so a component
overrides the theme it's installed on. An entry with no known rank defaults to lowest priority.

This reverses P1's deliberate parent-wins choice (user decision). It's safe and was the cheapest
moment to do it: block-layout already ships the whole stack to the client (`theme_block_layouts_json`
queries `Theme.transform_ids`), so it's a pure client-precedence flip; determinism is preserved
because the winner is keyed on the server-authoritative `stack_index` (not array order); and no
block-layout customization components existed in the wild yet, so nothing live reordered. The P1
resolver tests + the plugin `load-theme-block-layouts` ownership tests were flipped to most-derived
semantics; the shipped P1 doc carries a "superseded by A-P4" note, and the P3 doc's owner-targeting
line was updated. Everything downstream (`resolvedLayoutMeta`, `outletOwner`) reads "the winning
entry," so they followed automatically — `outletOwner` is now the most-derived owner.

## Core changes

- **`block-outlet.gjs`** — the §0 resolver flip (comment kept mechanism-only / plugin-agnostic).
- **`lib/application_layout_preloader.rb`** — `is_git` now derives from `remote_url` presence (LEFT
  JOIN `remote_themes`), matching `RemoteTheme#is_git?`, **not** `!remote_theme_id.nil?`. A locally
  imported theme (a duplicate, or a customization component) has no real `remote_url`, so it is
  correctly non-Git and publishable. (Adversarial-review blocking fix #1.)
- **`save_block_layout.rb` / `reset_block_layout.rb`** — the `theme_is_not_git` policies flipped from
  `remote_theme_id.nil?` to `theme.remote_theme&.is_git? != true`, so a locally-imported editable
  theme passes (else the duplicate/component would be non-Git to the editor but rejected at publish).
  Specs gained a "locally-imported theme is writable" case. (Adversarial-review blocking fix #1.)
- **`Themes::ExportBlockLayout`** (new, read-only) + `BlockLayoutsController#export` — live field value
  or a `layout_json` override, validated via `bake_block_layout!`, returned as
  `{ filename: "block_layouts/<outlet>.json", content: <pretty JSON> }`. 404 when no source, 422 on
  malformed.
- **`Themes::DuplicateForEditing`** (new) + `#duplicate` — exports the source via
  `ZipExporter#with_export_dir` and re-imports through the public
  `RemoteTheme.import_theme_from_directory(dir, before_save:)`, overlaying rename / `component` flag /
  `user_selectable=false` / the drafts inside the import transaction (atomic; a malformed draft rolls
  the whole import back). Re-links the source's child components. `Theme.uniquify_name` (new) handles
  `"<name> (copy)"` collision suffixes. (Adversarial-review fix #2: `before_save:` does NOT exist on
  `update_zipped_theme` — only on `import_theme_from_directory` — so the directory path is used.)
- **`Themes::CreateCustomizationComponent`** (new) + `#create_component` — revives the
  `<name>-customizations` child machinery P2 deleted from `save_block_layout.rb`
  (`ensure_customizations_component_for` / `ensure_child_link`), now explicit instead of silent:
  look up or create a local component, child-link it, overlay the drafts (transaction, bake-guarded).
  Works for ANY Git outlet thanks to §0.
- **`duplicable_theme` theme modifier** — a boolean column on `theme_modifier_sets` (auto-registered;
  default NULL = allowed). `DuplicateForEditing`'s `theme_is_duplicable` policy reads the source
  theme's own modifier directly (`theme.theme_modifier_set&.duplicable_theme != false`) — NOT
  `resolve_modifier_for_themes`, whose `.any?` stack-combine is wrong for an opt-out flag (it would
  read `false` for both "explicitly false" and "unset"). Gates Duplicate only, not create-component.
- Routes: `post block-layouts/{export,duplicate,customization-component}`; `service_params` permits
  `drafts: [:outlet_name, :layout_json]`.

## Plugin (client)

- `wireframe-live-layout.js` — `exportOutlet` / `duplicateTheme` / `createCustomizationComponent`
  verbs; a factored `#serializeLayoutJson` (refuse-on-null) reused by publish/export/draft-build;
  `#editedDrafts`; a `_triggerDownload` seam over the helper (stubbable in tests).
- `lib/download-json.js` (new, generically named) — Blob + object-URL anchor download; `content` is an
  already-serialized string, never re-stringified; deferred revoke; no navigation.
- `wireframe.js` — `exportOutlet` / `duplicateForEditing` / `createCustomizationComponent`
  orchestration (return `{themeId}` or an error string; no navigation, so they stay testable) +
  `navigateToEditTheme` (a thin, stubbable `window.location.assign(<currentPath>?wf_theme=<id>)` seam).
- `components/editor/inspector-outlet-section.gjs` — the Git branch (notice + Create-component +
  Export + Duplicate, with `dialog.confirm` for the two theme-producing actions, an in-flight
  `isWorking` disable, and inline error). The component owns the navigation after a successful action.
  The PUBLISHED badge now names the owning theme ("Published by `<theme>`") so an override is
  trackable.
- i18n under `wireframe.outlet.*`; SCSS for the badges, verbs, and Git block.

## Deviations from the original doc

- **Outlet-name `:`→`__` encoding DROPPED** (user-corrected): outlet names are kebab-case by contract
  (`VALID_BLOCK_NAME_PATTERN`, no `_`/`:`), so a namespaced `:` outlet can't exist and the existing
  `block_layouts/<outlet>.json` path already round-trips every real outlet. No `ThemeField` change.
- **Component-overrides-parent (§0)** was not in the original doc — added on the user's call, making
  create-component a complete escape hatch for any Git outlet (not just code-defaults).
- **`edit_url` re-entry** superseded: the client navigates (hard reload) to a `?wf_theme=` content
  route, not the theme admin page; an in-place `enter()` would render against absent layers/meta.

## Carried forward / out of scope

- A duplicate/component still shows a non-nil `remote_theme_id` in the *classic* theme admin
  serializers (cosmetic; the block-layout editor doesn't depend on it).
- The "Overriding `<base>` via `<component>`" two-theme label was reduced to "Published by `<owner>`"
  (the trackable signal) — naming the overridden base needs a new production accessor for the
  non-winning theme entries; deferred.
- `Duplicate` is shown for all Git outlets and returns 422 if the theme set `duplicable_theme: false`
  (clear message); hiding the button client-side would need `duplicable` threaded into the preload.

## Verification (all green)

- **qunit** — full plugin suite 443/443; core `block-outlet` 68/68 + `resolved-layout` 6/6 flipped to
  most-derived; new persistence export/duplicate/create-component verb tests; the inspector Git-branch
  render test (notice + 3 verbs + Publish disabled). `ember-tsc` clean.
- **rspec** — 82 examples across the preloader is_git regression, both policy flips (+ locally-imported
  writable case), `export`/`duplicate`/`create_component` services + request specs (round-trip via
  `opts_from_file_path`, full clone, collision suffix, component source, malformed → 422, modifier opt-out,
  non-admin → 404).
- **lint + `/discourse-code-conventions`** — clean (3 minor findings applied: `_triggerDownload`
  reorder; two missing `@returns`).
