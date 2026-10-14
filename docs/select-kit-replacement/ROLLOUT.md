# Rollout: replacing select-kit behind an upcoming change

How the select-kit replacement reaches production. This supersedes the RFC's "Migration
strategy" section (`SELECT-KIT-REPLACEMENT-RFC.md`), which planned a direct swap with no runtime
switch. Decided 2026-10-14, after audits of core, the bundled plugins and the official,
third-party and hosted-customer plugin and theme repositories, a prior-art review of 12
upcoming-change flags, and red-team reviews by Codex and Fable.

Paths are relative to the repository root.

## Decisions

1. **One upcoming-change flag; picker families join it as they reach parity.** Proposed name
   `enable_new_select_controls`, with `body_class: true` so themes can scope CSS to it.
2. **The new components honour `api.modifySelectKit`.**
3. **`api.modifyClass` on select-kit gets no fallback.** Known repos are ported. A deprecation
   throws in development and notifies admins in production, for families that have joined.
4. **FormKit's `select` and `tag-chooser` controls and `DNativeSelect` are in scope.**
5. **DMenu or DSelect is decided per consumer by the guideline below**, not by which select-kit
   class the consumer uses today.
6. **Core and bundled plugins migrate to the new API, and the switch lives at each call site.**
7. **Third parties stay on legacy select-kit with a deprecation.** Legacy modules are untouched,
   so third-party invocations and subclasses keep working.
8. **Waves run least-ready first**, while `DSelect` has no production consumer and an API change
   is cheapest.

## Blast radius

- **Core:** 154 files import select-kit, with 13 core subclasses: 10 `DropdownSelectBox` action
  menus, `DAccessControlGranteeChooser` (reads `this.selectKit.options`,
  `frontend/discourse/app/ui-kit/d-access-control-grantee-chooser.gjs:71`), and the site-text theme
  selector and its row. `ComboBox` alone has 76 invocations in 51 files.
- **Core SCSS:** 80 files under `app/assets/stylesheets` reference `select-kit`, 27 of them in
  `common/select-kit/`. The rest are layout rules in the composer, modals, admin and sidebar.
- **Bundled plugins:** 82 files import select-kit (172 mention it, tests included), 19 subclasses
  in 9 plugins, 4 `modifySelectKit` calls (all discourse-ai), 31 SCSS files.
- **FormKit and native selects:** 37 files with 64 `@type="select"` fields, 6 direct
  `DNativeSelect` consumers, and the FormKit `tag-chooser` control
  (`frontend/discourse/app/form-kit/components/fk/control/tag-chooser.gjs:15`). Both controls are
  global types (`frontend/discourse/app/form-kit/lib/field-control.js:36-37`) and are also yielded
  through `frontend/discourse/app/form-kit/components/fk/field.gjs:107`.
- **Tests:** 154 JS test files call `selectKit()`; about 113 system specs reach the `SelectKit`
  page object. Some page objects pass `.select-kit` roots into it
  (`spec/system/page_objects/pages/tag.rb:40`, `spec/system/page_objects/pages/group.rb:32`), and
  `frontend/discourse/tests/helpers/form-kit-helper.js:52` builds a `.select-kit` selector.
- **`api.modifyClass` on select-kit, across all repos: 29 calls in 16 repos.** One is bundled
  (discourse-assign patches `topic-notifications-button` at
  `plugins/discourse-assign/assets/javascripts/discourse/initializers/extend-for-assigns.js:330`;
  that component is not a select-kit subclass). Ten are customer repos and five third-party. They
  apply today because the resolver's suffix lookup
  (`frontend/discourse/app/resolver.js:115-128`) maps names like `component:category-drop` to the
  select-kit module.
- **`api.modifySelectKit`, across all repos:** discourse-ai (bundled) and one customer plugin,
  which reads `component.content`, `elementId`, `value` and `selectKit.options`, beyond what the
  bridge facade offers today.
- **Core code coupled to select-kit markup:** `frontend/discourse/app/controllers/signup.js:371-375`,
  `frontend/discourse/app/components/user-fields/base.js:28`,
  `frontend/discourse/app/components/composer-user-selector.gjs:22`,
  `frontend/discourse/admin/routes/admin-customize-themes/show/index.js:80`,
  `frontend/discourse/app/ui-kit/d-modal.gts:469`, `frontend/discourse/app/lib/roving-button-bar.js:51`,
  and the prosemirror onebox and link toolbars.
- **Implicit two-way binding** (no `onChange`): about 15 sites, plus the wizard's dynamic
  `{{component}}` (`frontend/discourse/app/static/wizard/components/fields/dropdown.gjs:87-120`).

## Rollout architecture

- **Flag lifecycle.** `promote_upcoming_changes_on_status` defaults to `beta`
  (`config/site_settings.yml:643`), and `UpcomingChanges.enabled?` force-enables a change at that
  status on every site (`lib/upcoming_changes.rb:266-281`). **Beta is the production rollout.**
  Alpha is opt-in. Stored group targeting excludes anonymous users at any status, `permanent`
  included (`lib/upcoming_changes.rb:330-337`).
- **Boot snapshot.** Per-user values are preloaded (`lib/application_layout_preloader.rb:131`) and
  overlaid on site settings before initializers run
  (`frontend/discourse/app/services/site-settings.js:30-46`). A thin service snapshots the flag
  eagerly at a documented boot point. Call sites, the body class and the deprecation gates all read
  that snapshot, so a live setting push (`lib/site_setting_extension.rb:901`) never swaps an open
  picker or splits CSS from markup. The service exposes a test helper and the list of families
  that have joined.
- **The switch lives at each migrated call site.** `{{#if <service>.enabled}}` renders the new
  component on its final API, and `{{else}}` keeps the select-kit invocation untouched, so the
  flag-off path is exactly today's code. Every branch carries a
  `TODO (select-kit-replacement-cleanup)` marker. Dynamic invocations (the wizard,
  `registerTopicFooterDropdown`) switch through a component map or a registration option instead of
  a template branch.
- **State must survive a mode change.** Both branches write the same parent-model shape. For
  example, the composer stores `MiniTagChooser`'s first argument in `model.tags`
  (`frontend/discourse/app/components/composer-container.gjs:483`), which `serializeTags`
  (`frontend/discourse/app/lib/serialize-tags.js`) expects as names or tag objects, while `DSelect`
  emits ids. A draft saved in one mode must load in the other.
- **`modifySelectKit` contract.** The facade contract is written as test fixtures that mirror real
  callers, per family: discourse-ai reads `element` (inside `#reply-control`) and
  `selectKit.filter`, `value`, `set`, `select`, `close`, `triggerSearch` and `isLoading`; the
  customer plugin reads `content`, `elementId`, `value` and `selectKit.options`. Bridge gaps to
  close: `triggerSearch`, a working `isLoading`, row `classNames`, per-callback rather than
  identifier-wide suppression, and per-use telemetry (the RFC asks for it; the bridge warns once
  per engine today).
- **`modifyClass` deprecation.** Detection happens after `_resolveClass`
  (`frontend/discourse/app/lib/plugin-api.gjs:3965-3986`) by testing whether the resolved class is
  a select-kit component. The existing hook at `plugin-api.gjs:3943` runs before resolution and
  only sees the name. Testing the class catches nested names such as
  `component:select-kit/select-kit-row` and third-party subclasses. It fires only for families
  that have joined the flag, once per source and target, with the source taken from `api.source`
  (`plugin-api.gjs:217-228`). It throws in development (a workflow entry with
  `env: "development"`) and uses `notify-admin` in production. A family joins only after the known
  repos that patch it are ported, so the throw only stops boot for unknown code. A plugin
  initializer's throw stops boot (`frontend/discourse/app/app.js:363-364`), so the message names
  the target, the source and the migration guide. Admin notices only reach admins' own sessions
  and are deduplicated by id (`frontend/discourse/app/services/deprecation-warning-handler.js:49-63`);
  they need to be keyed by id and source.
- **Third-party deprecation.** Attribution happens at import time, because the render stack has no
  theme frame: a non-core module importing `discourse/select-kit/components/*` for a family that
  has joined. Ids use a `discourse.select-kit-rollout.*` namespace so the existing silence rules
  (`frontend/discourse/app/deprecation-workflow.js:311-321`) don't swallow them.
- **Supported replacements for today's patches.** A patch-by-patch matrix maps each known
  customization (caret and icon, `showFullTitle`, content filtering, row titles, selection labels,
  opening behaviour, notifications `reasonText`) to a supported API. A family joins only once its
  ports are done.
- **CSS.** DSelect's temporary `.d-combobox` root flips to `.d-select` before wave 1
  (`app/assets/stylesheets/common/components/d-combobox.scss:1-3`; the `DNativeSelect` rename it
  waited on has landed). Each family migrates the core and plugin SCSS that targets it. Layout
  bridging goes in `app/assets/stylesheets/common/upcoming-changes/`.
- **Enter in modals.** `frontend/discourse/app/ui-kit/d-modal.gts:51-63,465-469` exempts
  `.select-kit` from Enter-to-submit but not `role="combobox"`, so Enter in a `DSelect` inside a
  modal without a form submits the modal. This is a live `DSelect` bug, fixed test-first in wave 0.

## DMenu or DSelect

Based on the WAI-ARIA APG menu button and select-only combobox patterns:

- **DSelect** when the control holds a current value that the list chooses among and the trigger
  reflects it: settings, filters, notification levels, breadcrumbs. Use the static variant for
  short fixed lists and the typeahead when filtering helps. Command rows inside a value select are
  action rows.
- **DMenu** when the items run one-off commands and the trigger label is fixed.
- **Toggle sets** are a `DSelect` with `@multiple`.

Applied to the ambiguous consumers:

- **DSelect:** the notifications-button family, period chooser, notifications filter, group
  dropdown, the composer's translation selector
  (`frontend/discourse/app/components/composer-container.gjs:371`), and the sidebar's edit filter
  (`frontend/discourse/app/components/sidebar/edit-navigation-menu/modal.gjs:90`).
- **DMenu:** the 10 `DropdownSelectBox` subclasses, user deletion
  (`frontend/discourse/app/templates/user/collapsed-info.gjs:100`,
  `frontend/discourse/admin/templates/admin-user/index.gjs:1000`), reviewable bundled actions, the
  category and tag admin dropdowns, and bulk-select bookmarks. These still have to run
  `modifySelectKit` callbacks registered on their identifiers, since DMenu has no bridge.
- **Per registration:** `registerTopicFooterDropdown` gets an opt-in key.

## Waves

Least-ready first: the families that need the most new capability and carry the most
customization go first. Hard dependencies come before them in wave 0, and shared infrastructure
lands before its consumers. A family joins the flag only when its call sites are branched, its
state survives a mode change, its specs pass in both modes, its SCSS is migrated, and its
customization ports are done.

- **Wave 0, foundations.** The flag (experimental) and boot snapshot; the `.d-select` root; the
  modal Enter fix; the `modifyClass` and third-party deprecations; bridge contract fixtures and
  gaps; test infrastructure that drives either implementation (the page object, `selectKit()`,
  `form-kit-helper.js`, and callers' `.select-kit` roots), with specs pinning the flag. Plus prep
  that also works with select-kit: explicit `onChange` at the two-way sites, stable hooks in place
  of `.select-kit` DOM queries, and the wizard's `onChange`.
- **Wave 1, tags and categories, composer included.** Tag and category choosers, drops and
  selectors, FormKit's `tag-chooser`, and the search and report choosers. Category rows reuse
  `categoryBadgeHTML` (`frontend/discourse/select-kit/components/category-row.gjs:123`); tag rows
  reuse `dDiscourseTag` and `renderTag` (`frontend/discourse/app/ui-kit/helpers/d-discourse-tag.js:5`).
  discourse-ai's suggesters and the customer `modifySelectKit` plugin are ported. Staff skip tag
  validation (`frontend/discourse/app/services/composer.js:688`), so the alpha cohort includes a
  non-staff group, and member and anonymous paths are covered before exposure.
- **Wave 2, entity pickers and ui-kit wrappers.** The user, email-group-user and group choosers (a
  user search preset, `addUserSearchOption`, `customSearchOptions`, a rewritten
  `DAccessControlGranteeChooser`), topic, form template, timezone, flair, list setting, tag group,
  color, font and wizard pickers. The ui-kit wrappers move together as one family:
  `d-time-input`, `d-relative-time-picker`, `d-future-date-input` with its
  `FutureDateInputSelector`, and `d-access-control`.
- **Wave 3, menu-shaped value selects and action menus.** The notifications buttons, group
  dropdown and value-type `DropdownSelectBox` uses become `DSelect`; action menus become `DMenu`.
  Customer ports for the notifications buttons and discourse-assign's `reasonText` patch land here.
- **Wave 4, generic value selects and native selects.** `ComboBox` and `MultiSelect` with static
  content, FormKit's `select`, `DNativeSelect` (value types, empty values, disabled state, labels and
  errors, form participation, and query parameters in
  `frontend/discourse/app/ui-kit/d-filter-controls.gjs:259,409`), the period chooser and the
  notifications filter. FormKit controls are global types, so this wave decides between new control
  types and a switch inside the shared control.
- **Wave 5, bundled plugin subclasses** (19), the remaining plugin SCSS, and the remaining
  customer ports.

## Promotion

- **Alpha** (staff plus a member group) after wave 1, then a soak with `Everyone` on hosted sites.
- **Beta gates.** Beta is the production rollout, so all of these hold first: every family has
  joined; every known `modifyClass` and `modifySelectKit` caller is ported and released; the
  third-party deprecation has been live for a defined period; group targeting can be cleared;
  both-mode specs for high-traffic and anonymous paths pass; and per-id deprecation counts by
  source are below a named threshold.
- **Stable, then permanent.** At `permanent`, the `else` branches and legacy-only code in core and
  bundled plugins are deleted, and a lint rule bans select-kit there, with named exceptions (the
  bridge's `select-kit/lib/plugin-api` import, compat-modules, retained styles).
- **Select-kit stays,** frozen and deprecated, for third parties.
- **Rollback** of a family is a release-level revert. The flag doesn't change a session that has
  already booted.

## Verification

- **Per family:** call-site tests and system specs in both modes that assert which implementation
  rendered; state round trips across modes; legacy and new controls mixed on one page; member,
  staff and anonymous paths; Foundation and Horizon, light and dark, mobile (DSelect opens a
  DModal) and screen readers; `script/check_strict_types` and `pnpm lint:types` clean.
- **`modifyClass` deprecation:** boot tests with bundled, customer and theme initializers; nested
  names, deferred targets, static modifications, and targets that aren't select-kit; per-source
  deduplication.
- **Before beta:** the customer repos' own specs pass with the flag on.
