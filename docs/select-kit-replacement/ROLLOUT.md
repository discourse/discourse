# Rollout: replacing select-kit behind an upcoming change

How the select-kit replacement reaches production. This supersedes the RFC's "Migration
strategy" section (`SELECT-KIT-REPLACEMENT-RFC.md`), which planned a direct swap with no runtime
switch. Decided 2026-10-14, after audits of core, the bundled plugins and the official,
third-party and hosted-customer plugin and theme repositories, a prior-art review of 12
upcoming-change flags, and red-team reviews by Codex and Fable.

Paths are relative to the repository root.

## Decisions

1. **One upcoming-change flag; picker families join it as they reach parity.** The flag is
   `enable_new_select_controls`. A family joins when its converted call sites merge; there is no
   runtime list of families. `body_class: true` comes when the first family needs CSS scoped to it.
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
9. **Specialized `DSelect` components are called recipes**, not presets. Earlier documents use the
   old name.
10. **Recipes reach feature parity in the application, not API parity with select-kit.** Each
    family's recipe set is designed by purpose: what is picked, from where, and what the call site
    does with the pick. Recipes that differ only by configuration are one recipe. Arguments,
    terminology and component names are chosen for the new API rather than copied, and behaviour
    lives at the layer that owns it (navigation belongs to the call site, not to a picker).
    Compatibility with third-party customizations (bridge kinds, legacy root classes) is kept by
    mapping, never by mirroring select-kit's component structure. Decided 2026-10-21. For tags
    this produced `DSelectTag`, `DSelectTagFilter` and `DSelectTagGroup` (kinds named after the
    components); each instance keeps its select-kit name(s) through `@legacyKind` for the bridge
    and legacy CSS. That match is per instance, so it is narrower than select-kit's class chain:
    only the intersection filter also answers to `mini-tag-chooser`.

## Blast radius

- **Core:** 154 files import select-kit, with 13 core subclasses: 10 `DropdownSelectBox` action
  menus, `DAccessControlGranteeChooser` (reads `this.selectKit.options`,
  `frontend/discourse/app/ui-kit/d-access-control-grantee-chooser.gjs:71`), and the site-text theme
  selector and its row. `ComboBox` alone has 76 invocations in 51 files.
- **Core SCSS:** 80 files under `app/assets/stylesheets` reference `select-kit`, 27 of them in
  `common/select-kit/`. The rest are layout rules in the composer, modals, admin and sidebar.
- **Bundled plugins:** 82 files import select-kit (172 mention it, tests included), 20 subclasses
  in 10 plugins (verified 2026-10-19), 4 `modifySelectKit` calls (all discourse-ai), 31 SCSS files.
- **FormKit and native selects:** 37 files with 64 `@type="select"` fields, 6 direct
  `DNativeSelect` consumers, and the FormKit `tag-chooser` control
  (`frontend/discourse/app/form-kit/components/fk/control/tag-chooser.gjs:15`). Both controls are
  global types (`frontend/discourse/app/form-kit/lib/field-control.js:36-37`) and are also yielded
  through `frontend/discourse/app/form-kit/components/fk/field.gjs:107`.
- **Tests:** 154 JS test files call `selectKit()`; about 113 system specs reach the `SelectKit`
  page object. Some page objects pass `.select-kit` roots into it
  (`spec/system/page_objects/pages/tag.rb:40`, `spec/system/page_objects/pages/group.rb:32`), and
  `frontend/discourse/tests/helpers/form-kit-helper.js:52` builds a `.select-kit` selector.
- **`api.modifyClass` on select-kit, across all repos: 30 calls in 17 repos**, from a verified
  audit on 2026-10-16. Each call was checked against what core renders today.
  - 16 calls, in 10 repos, change core's selects today. One of them, a customer patch on
    `notifications-button`, was first counted dead: core still renders that class in group
    settings (`frontend/discourse/app/components/groups-form-interaction-fields.gjs:162`).
  - 2 change only the patching plugin's own selects.
  - 1 only does harm: it skips a lifecycle `super`.
  - 10 are already dead: they override removed members, sit in files whose imports no longer
    resolve, or patch classes core no longer renders.
  - discourse-assign's patch on `topic-notifications-button`
    (`plugins/discourse-assign/assets/javascripts/discourse/initializers/extend-for-assigns.js:330`)
    is out of scope. That component is a Glimmer wrapper around the DMenu-based
    `NotificationsTracking`.

  Name-based patches reach select-kit through the resolver's suffix lookup
  (`frontend/discourse/app/resolver.js:115-128`), which maps names like `component:category-drop`
  to the select-kit module. A patch on `dropdown-select-box` reaches only direct
  `DropdownSelectBox` invocations, not subclasses that declare their own options. An earlier count
  gave 29 calls in 16 repos; its list was not kept, so the difference is unattributed. The per-repo
  list names customer repos, so it is kept outside the repository.
- **Decorators applied to core classes:** one customer theme imports `CategoryDrop` and `TagDrop`
  and applies `selectKitOptions(...)` to them directly to change their carets. The decorator
  appends to the class's option list (`frontend/discourse/select-kit/components/select-kit.js:75`),
  so this reaches core's selects without `modifyClass`. The `modifyClass` audit didn't search this
  channel; a follow-up search found no other site.
- **Subclasses across all repos: 89** (86 direct, 3 through plugin-local subclasses), verified
  2026-10-19: 86 live, 3 dead. Live: 61 value selects, 8 action menus, 17 rows, headers and
  selected-choice parts. Each customizes only its own render, so none needs an extension point;
  the ports are plain `DSelect`, a core recipe with call-site arguments and blocks, or `DMenu`.
  The per-class list names customer repos, so it is kept outside the repository.
- **`api.modifySelectKit`, across all repos:** discourse-ai (bundled) and one customer plugin,
  which reads `component.content`, `elementId`, `value` and `selectKit.options`, beyond what the
  bridge facade offers today.
- **Core code coupled to select-kit markup:** the theme parent-themes focus, the composer
  recipients autofocus and the user-field validation target now find their element through
  `selectControl` (`frontend/discourse/app/lib/select-control.ts`), which knows both
  implementations. `frontend/discourse/app/ui-kit/d-modal.gts:469` exempts both from Enter.
  `frontend/discourse/app/lib/roving-button-bar.js:51` and the prosemirror onebox and link
  toolbars still name `.select-kit`, but no select renders there in core, and a focusable DSelect
  root already matches their generic selectors; they are revisited at cleanup.
- **Implicit two-way binding** (no `onChange`): verified 2026-10-20 by reading all 423 select-kit
  invocations in core and bundled plugins: 29 template sites (19 core, 10 bundled plugins) plus the
  wizard's dynamic `{{component}}`. All now pass an explicit `onChange`. The write-back emits
  `discourse.select-kit.implicit-mutation`, which is not silenced, so core and bundled plugin tests
  fail on any new two-way site; third-party code only logs it.
- **Customized multi-select panels:** button and mobile multi-selects no longer show a
  separate strip of held items between the search and the results. Picked items now render as
  chips inside the panel's search field. Plugins and themes that style or position the old strip
  in those panels (`.d-select__strip`) need to target the field (`.d-select__chips`) instead.
  Static selects and capped typeaheads keep the strip.

## Rollout architecture

- **Flag lifecycle.** `promote_upcoming_changes_on_status` defaults to `beta`
  (`config/site_settings.yml:643`), and `UpcomingChanges.enabled?` force-enables a change at that
  status on every site (`lib/upcoming_changes.rb:266-281`). **Beta is the production rollout.**
  Alpha is opt-in. Stored group targeting excludes anonymous users at any status, `permanent`
  included (`lib/upcoming_changes.rb:330-337`). The flag starts at `conceptual`, which needs no
  Meta topic and stays off the admin list, and moves to `experimental` with a Meta topic when wave
  1's first family joins (every status but `conceptual` requires a `learn_more_url`,
  `spec/integrity/upcoming_change_metadata_spec.rb:114-118`).
- **The flag is read live.** Per-user values are preloaded (`lib/application_layout_preloader.rb:131`)
  and overlaid on site settings before initializers run
  (`frontend/discourse/app/services/site-settings.js:30-46`), so call sites read
  `this.siteSettings.enable_new_select_controls` directly, as `enable_new_reordering_controls`
  does. A boot snapshot was considered and dropped: it only guards against an admin toggling an
  Everyone-targeted flag while a picker is open (group-targeted changes are never pushed live,
  `lib/site_setting_extension.rb:901-914`), and it would have needed its own body class and test
  helper to stay in step with the live value.
- **The switch lives at each migrated call site.** `{{#if this.siteSettings.enable_new_select_controls}}` renders the new
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
- **`modifySelectKit` contract.** Across the official, third-party and customer plugin and theme
  repositories, the only callers are discourse-ai and one customer plugin, and wave 1 ports both.
  The bridge therefore covers what any select can honour. The facade contract is written as
  fixtures that mirror both callers' generic reads (`d-select-bridge-test.gjs`, "modifySelectKit
  contract"):
  - `triggerSearch()` starts a new query;
  - `set("isLoading", …)` drives the trigger's pending state, and a `select()` made while it is
    set lands as that update's outcome unless the user picked by hand in the meantime;
  - `content` is the list entering the legacy stage, and `value` is the held value.

  Some reads stay with the customer port: `selectKit.options`, `elementId` plus the parent DOM,
  and the category components' own members. Reporting stays once per select per plugin. A ported
  plugin keeps its legacy callbacks for the flag-off branch, so the bridge needs a per-callback
  opt-out to avoid doubled rows; it is designed with the discourse-ai port in wave 1. Row
  `classNames` is not bridged: its one known user moves to `spec.row` classes when it is
  ported.
- **`modifyClass` deprecation** (`frontend/discourse/app/lib/select-kit-modify-class-deprecation.ts`).
  After `modifyClass` or `modifyClassStatic` applies a patch, it fires
  `discourse.select-kit-rollout.modify-class` when the patched class is exactly the default export
  of a module in `MIGRATED_SELECT_KIT_MODULES` and `enable_new_select_controls` is on. The set holds
  module paths (`"category-drop"`, `"select-kit/select-kit-row"`); a family adds its modules when
  its converted call sites merge, so a patch on a module core still renders is never reported. Only
  the exact class counts: a third-party subclass keeps rendering select-kit, so a patch on it keeps
  working. The flag is read last, because a container lookup instantiates and caches the service,
  which would stop it being patched later. The patch is applied first, so it still reaches
  third-party call sites. The deprecation throws in development and uses `notify-admin` in
  production; in development a plugin's throw stops its initializer and boot
  (`frontend/discourse/app/app.js:363-364`), and a theme's is reported as a theme error. A family
  joins only after the known repos that patch it are ported, so the throw only stops boot for
  unknown code. The console line names the plugin or theme from `api.source`; the admin notice
  stays one per id, as for every deprecation, and names the first source. The migration guide's URL
  is added with the Meta topic when the flag leaves conceptual.
- **Third-party notice, render-time, from wave 1.** When a legacy component of a migrated family
  renders while `enable_new_select_controls` is on, something that hasn't migrated rendered it;
  that is the signal. It is designed with wave 1's first family, attributed from the stack, under a
  `discourse.select-kit-rollout.*` id that the existing silence rules
  (`frontend/discourse/app/deprecation-workflow.js:311-321`) don't match. An import-time
  deprecation was dropped: plugin and theme bundles do reach core through
  `window.moduleBroker.lookup` (`frontend/asset-processor/babel-resolve-core-imports.js:32-45`), but
  migrated bundled-plugin call sites keep importing legacy select-kit for their `{{else}}` branch
  until cleanup, so it would fire for converted code too. Third-party code that renders select-kit
  doesn't break, so this is a nudge, not a guard.
- **Supported replacements for today's patches.** A matrix
  ([`PATCH-MATRIX.md`](PATCH-MATRIX.md)) maps each live customization to a supported API:
  - caret icons;
  - hiding the title text;
  - filtering the category list;
  - shortcut rows with their own change routing;
  - the none-row label;
  - row tooltips from item descriptions;
  - disabling choosers from an outside flow.

  A family joins only once its ports are done.
- **CSS.** DSelect uses the `.d-select` BEM root
  (`app/assets/stylesheets/common/components/d-select.scss`), which replaced the temporary
  `.d-combobox` in wave 0. Each family migrates the core and plugin SCSS that targets it. Layout
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

- **DSelect:** the period chooser, notifications filter, group
  dropdown, the composer's translation selector
  (`frontend/discourse/app/components/composer-container.gjs:371`), and the sidebar's edit filter
  (`frontend/discourse/app/components/sidebar/edit-navigation-menu/modal.gjs:90`).
- **DMenu:** the 10 `DropdownSelectBox` subclasses, user deletion
  (`frontend/discourse/app/templates/user/collapsed-info.gjs:100`,
  `frontend/discourse/admin/templates/admin-user/index.gjs:1000`), reviewable bundled actions, the
  category and tag admin dropdowns, and bulk-select bookmarks. These still have to run
  `modifySelectKit` callbacks registered on their identifiers, since DMenu has no bridge.
- **Per registration:** `registerTopicFooterDropdown` gets an opt-in key.
- **Open decision: the notification-level family.** Topic, category and tag notifications, and a
  group's messages, use the DMenu-based `NotificationsTracking`
  (`frontend/discourse/app/components/notifications-tracking.gjs`). Group settings still render the
  select-kit `NotificationsButton` for the default level
  (`frontend/discourse/app/components/groups-form-interaction-fields.gjs:162`), and plugins and
  themes subclass it. Two themes show the level's `label` in the trigger, which
  `NotificationsTracking` doesn't. The choice is between reusing `NotificationsTracking` and a
  notification-level `DSelect` recipe.

## Waves

Least-ready first: the families that need the most new capability and carry the most
customization go first. Hard dependencies come before them in wave 0, and shared infrastructure
lands before its consumers. A family joins the flag only when its call sites are branched, its
state survives a mode change, its specs pass in both modes, its SCSS is migrated, and its
customization ports are done.

- **Wave 0, foundations.** The flag (conceptual); the `.d-select` root; the
  modal Enter fix; the `modifyClass` deprecation; bridge contract fixtures and
  gaps; test infrastructure that drives either implementation (the page object, `selectKit()`,
  `form-kit-helper.js`, and callers' `.select-kit` roots), with specs pinning the flag. Plus prep
  that also works with select-kit: explicit `onChange` at the two-way sites, stable hooks in place
  of `.select-kit` DOM queries, and the wizard's `onChange`.
- **Wave 1, tags and categories, composer included.** Tag and category choosers, drops and
  selectors, the tag group chooser, FormKit's `tag-chooser`, and the search and report choosers. Category rows reuse
  `categoryBadgeHTML` (`frontend/discourse/select-kit/components/category-row.gjs:123`); tag rows
  reuse `dDiscourseTag` and `renderTag` (`frontend/discourse/app/ui-kit/helpers/d-discourse-tag.js:5`).
  discourse-ai's suggesters and the customer `modifySelectKit` plugin are ported. Staff skip tag
  validation (`frontend/discourse/app/services/composer.js:688`), so the alpha cohort includes a
  non-staff group, and member and anonymous paths are covered before exposure.
  Status 2026-10-26: the tag family has joined; every category call site is branched, with the
  recipe follow-ups and the screen-reader pass still open (`PHASE-3.md`).
- **Wave 2, entity pickers and ui-kit wrappers.** The user, email-group-user and group choosers (a
  user search recipe, `addUserSearchOption`, `customSearchOptions`, a rewritten
  `DAccessControlGranteeChooser`), topic, form template, timezone, flair, list setting, color, font
  and wizard pickers. The ui-kit wrappers move together as one family:
  `d-time-input`, `d-relative-time-picker`, `d-future-date-input` with its
  `FutureDateInputSelector`, and `d-access-control`.
- **Wave 3, menu-shaped value selects and action menus.** The group dropdown and value-type
  `DropdownSelectBox` uses become `DSelect`; action menus become `DMenu`. Customer ports for the
  live patches on direct `DropdownSelectBox` invocations (caret icons and hidden titles) land here.
- **Wave 4, generic value selects and native selects.** `ComboBox` and `MultiSelect` with static
  content, FormKit's `select`, `DNativeSelect` (value types, empty values, disabled state, labels and
  errors, form participation, and query parameters in
  `frontend/discourse/app/ui-kit/d-filter-controls.gjs:259,409`), the period chooser and the
  notifications filter. FormKit controls are global types, so this wave decides between new control
  types and a switch inside the shared control.
- **Wave 5, bundled plugin subclasses** (20), the remaining plugin SCSS, and the remaining
  customer ports.

## Promotion

- **Alpha** (staff plus a member group) after wave 1, then a soak with `Everyone` on hosted sites.
- **Beta gates.** Beta is the production rollout, so all of these hold first: every family has
  joined; every known `modifyClass` and `modifySelectKit` caller is ported and released; the
  render-time third-party notice has been live for a defined period; group targeting can be cleared;
  both-mode specs for high-traffic and anonymous paths pass; and per-id deprecation counts by
  source are below a named threshold.
- **Stable, then permanent.** At `permanent`, the `else` branches and legacy-only code in core and
  bundled plugins are deleted, and a lint rule bans select-kit there, with named exceptions (the
  bridge's `select-kit/lib/plugin-api` import, compat-modules, retained styles).
- **Select-kit stays,** frozen and deprecated, for third parties.
- **Rollback** of a family is a release-level revert. The flag doesn't change a session that has
  already booted.

## Pending audits

- **Customizable display text.** Inventory every string the select components display or
  announce, such as placeholders, the search placeholder, the empty and error states, limit
  messages, the "N selected" count, the create row, the none row, chip hints, remove-button names
  and live announcements. Then confirm that the API lets a call site override each one, and that
  every recipe exposes the same overrides instead of fixing them. Strings that cannot be overridden
  get an argument or a `@kindOptions` key before the families that render them join the flag.
  Requested 2026-10-23. **Done 2026-10-30:** every text DSelect or a recipe draws or speaks is a
  key in one `@texts` hash, and customizations set it under `texts` (README, "Texts"). The old
  `@ariaLabel`, `@placeholder`, `@searchPlaceholder`, `@noResultsLabel`, `@noneLabel` and
  `@loadingLabel` arguments are gone; the none row and the loading status are switches
  (`@noneRow`, `@loadingStatus`). New strings: `d_select.none`, `d_select.loading`,
  `d_select.compact_count`, `d_select.more_chips`, `tagging.tag_count_badge`,
  `tagging.add_more_tags`, `tagging.choose_more_required`, `tagging.choose_more_required_group`,
  `tagging.required_tags_progress`, `tagging.max_tags_reached` and
  `tagging.filter_to_narrow_tags` (unused until the tag drop gets `@maxLoaded`).
  `d_select.label_with_count` became a plural key and the unused `d_select.expand` is deleted.
  The category badge helper's own texts ("× N", "+ Subcategories", "read-only") keep the site
  wording, which Admin › Customize › Text changes.
  - Categories, 2026-10-26: the filter keeps select-kit's lowercase strings (`categories`,
    `subcategories`, `no subcategories`, `remove filter`, `view all`), as the tag filter does, so
    the navigation bar reads the same in both modes. The level name is the empty level's
    placeholder, overridable with a `placeholder` text from the call site or a customization, and
    the drop is named by `categories.filter_by_categories_label` / `filter_by_subcategories_label`
    ("Filter by: categories", 2026-10-28). The family footer's names, "%{category} and all subcategories"
    (`category.select_with_subcategories`) and "%{category} (%{count} topics) and all
    subcategories" (`category.select_with_subcategories_count`), are placeholder strings, so
    translations can reorder them.
  - Categories, 2026-10-29: a category picker with no caption is named "Category"
    (`categories.category`), or "Categories" (`categories.categories`, new) when it can hold
    more than one. Before, its placeholder was its name.
  - Tags, 2026-10-29: the tag filter is named "Filter by: tags" (`tagging.filter_by_tags_label`,
    new). With nothing filtered it holds nothing and shows "tags" (`tagging.selector_tags`) as its
    placeholder, overridable with a `placeholder` text from the call site or a customization; the
    intersection drop shows the same instead of "Optional tags…".
  - Tags, 2026-10-30: a tag picker with no caption is named "Tag" (`tagging.tag`, new) or
    "Tags" (`tagging.tags`) when it can hold more than one, and a tag group picker "Tag group"
    (`tagging.tag_group_label`, new) or "Tag groups" (`tagging.tag_groups_label`, new). Before,
    they read "Options". The composer's tag field is named "Tags" instead of "Optional tags…",
    which stays its placeholder.
- **Theme CSS.** Before a family joins the flag, search customer themes for the legacy selectors
  it renders and map each one to the DSelect equivalent below; a hit with no equivalent is a gap
  to close in core or a theme fix to hand over. Requested 2026-10-23; extend the table as each
  family is converted. Two traps found while porting the tag drop apply to every family:
  - **In the `button` and `static` variants the root IS the trigger.** `.d-select.tag-drop` and
    `.d-select__trigger` are the same element, so a descendant selector such as
    `.d-select.tag-drop .d-select__trigger` (the shape a mechanical port of
    `.select-kit.tag-drop .select-kit-header` produces) never matches. Core had two such rules
    (`list-controls.scss`, the modernize theme's hover) that silently did nothing.
  - **The panel is portaled.** Selectors scoped under the root or a page container
    (`.list-controls .select-kit .select-kit-collection`) cannot reach rows, the search field or
    the footer. Panel styles key on the overlay's kind modifier,
    `.d-select__content.--kind-<kind>`.

  | Legacy selector (tag drop) | DSelect equivalent |
  |---|---|
  | `.select-kit.tag-drop` | `.d-select.tag-drop` (root and trigger) |
  | `.tag-drop-header`, `.select-kit-header` | `.d-select.tag-drop` itself |
  | `.select-kit.tag-drop.has-selection` | `.d-select.tag-drop.--filtering` (a tag or untagged) |
  | `.is-expanded`, `.is-focused`, `.is-highlighted` on the header | `[aria-expanded="true"]`, `:focus`, `:focus-visible` on the root |
  | `.selected-name` | `.d-tag-drop__selection` (a held tag), `.d-select__placeholder` ("tags") |
  | `.caret-icon`, `.angle-icon` | `.d-select.tag-drop .d-select__caret` (the core `caretIcon` option for the glyph) |
  | `.select-kit-body` | `.d-select__content.--kind-select-tag-filter` (width: `--d-select-menu-min-width`) |
  | `.select-kit-collection` | `.d-select__panel` (height: `--d-select-panel-max-height`) |
  | `.select-kit-filter`, `.filter-input` | `.d-select__search`, `.d-select__filter` |
  | `.filter-icon` | `.d-select__search-icon` (`@searchIcon` / the `searchIcon` option for the glyph) |
  | `.select-kit-row`, `.is-highlighted`, `.is-selected` | `.d-select__option`, `.--active`, `[aria-selected="true"]` |
  | `.select-kit-row[data-value="all-tags"]`, `[data-value="no-tags"]` | `.d-tag-drop__shortcut` (rows keep `data-value`) |
  | `.select-kit-row .discourse-tag-count` | `.d-tag-option .discourse-tag-count` |
  | `.filter-for-more` | `.d-tag-drop__filter-for-more`, inside `.d-select__footer` |

  | Legacy selector (category pickers) | DSelect equivalent |
  |---|---|
  | `.select-kit.category-chooser`, `.category-selector`, `.multiple-categories-selector`, `.category-drop` | `.d-select` with the same class (the root; for the drop it is also the trigger) |
  | The 300px default width of `.select-kit.combo-box` and `.select-kit.multi-select` | None: DSelect fills its container, so the call site sets a width |
  | `.category-drop-header`, `.select-kit.category-drop.has-selection` | `.d-select.category-drop` itself; there is no selection modifier yet, so this is a gap |
  | `.selected-name` on the drop | `.d-category-filter__selection` |
  | `.select-kit-body` | `.d-select__content.--kind-select-category` or `.--kind-select-category-filter` |
  | `.select-kit-row.category-row` | `.d-select__option`; the badge is the option label, with no `.category-status` wrapper |
  | `.category-row .category-desc` | `.d-select__option-description` |
  | `.category-row .topic-count`, `.read-only` | `.d-select__option .topic-count`, `.read-only` |
  | `.select-kit-row[data-value="all-categories"]`, `[data-value="no-categories"]` | `.d-select__option` with the same `data-value` |
  | `.plus-subcategories` | The same class, inside the family footer `.d-select__option.--action-footer[data-value^="category-descendants-"]` |
  | `.selected-choice-category` | `.d-select__chip` |
  | `.category-drop-footer` | No equivalent: the new drop has no footer |

## Behaviour changes to compare by hand

Differences from select-kit to try side by side (flag on and off) before a family is promoted.
Open items need a decision after manual testing; the rest are intended but still worth seeing.

**Categories** (recorded 2026-10-24)

- [ ] **Open: typing does not highlight the first match.** Select-kit highlights the first row as
  soon as a query is typed, so Enter picks it (`select-kit.js:1070-1076`, unless a single select
  already holds a value). In DSelect's `button` variant nothing is active until an arrow key
  moves to a row. Kept for now; changing it would change every `button`-variant select, so decide
  after testing the composer chooser and the breadcrumb drop.
- [ ] **No blank trigger.** With Uncategorized disallowed and `default_composer_category` set,
  the legacy chooser shows an empty header. The new one shows "Choose a category…". The composer
  fills in the default category itself, so the blank state only showed briefly or outside the
  composer.
- [ ] **Breadcrumb search is not capped at 5 and matches names only.** The legacy drop shows at
  most five results in local mode and also matches slugs; the new filter lists every match through
  the shared search, ranked the server's way, on both kinds of site. A category whose slug alone
  matched is no longer offered.
- [ ] **The breadcrumb drop leaves out muted subcategories everywhere.** Both drops hid a
  category muted only through its parent while browsing a preloaded site, because the navigation
  filtered the list it passed. The legacy drop still listed it in searches and on lazy sites; the
  new one leaves it out everywhere. A category muted directly stays listed in both.
- [ ] **Lazy loading pages instead of stopping.** The legacy chooser and selector make one search
  request and show its first 25 rows; the new ones keep paging as you scroll. The legacy
  breadcrumb drop showed 15 rows with "+N more · view all" for a long level; the new one pages
  through the whole level in the preloaded order, with no count and no link to the categories
  page.
- [ ] **The breadcrumb drop names what it filters.** An empty level shows the level name as a
  placeholder and is named "Filter by: categories" / "Filter by: subcategories"; with a pick it
  reads "Filter by: subcategories, Rock", where select-kit read "Filter by: Rock". A held "no
  subcategories" filter offers "remove filter".
- [ ] **"+ Subcategories" includes every level.** In lazy mode the legacy row missed
  grandchildren; the new one adds the whole tree, minus excluded categories.
- [ ] **"+ Subcategories" follows each family.** The legacy selector offered the row only when
  one category matched or the first match had the exact name, right below it. The new picker
  groups every search of two or more characters by family and offers the row right after each
  family's category, at every level, drawn with the category's badge and topic count.
- [ ] **Browsing is in tree order on lazy sites too.** The legacy lazy chooser kept the server's
  order: top-level categories first, then by id. Both modes now list each category after its
  parent, with siblings by topic count, or by position when `fixed_category_positions_on_create`
  is on. On lazy sites, a category whose parent the user cannot see is listed as a top-level
  category.
- [ ] **Searching ranks the server's way in both modes.** The legacy eager chooser filtered its
  activity order; the new one ranks prefix matches and top-level categories first, as the server
  does, and keeps each family together.
- [ ] **Single choosers match the category's own name.** The legacy eager chooser also matched a
  subcategory by its parent's name. Lazy sites never did, and now neither mode does.
- [ ] **`_` and `%` match literally.** On a lazy site, the legacy search treated them as
  wildcards, so `_` matched every category.
- [ ] **Read-only categories are listed at the top.** The legacy eager chooser kept the
  composer's read-only category in its sorted place; it is now a disabled row above the list in
  both modes, as it already was on lazy sites.
- [ ] **Pickers are named by their caption.** Select-kit left the caption beside a picker
  unassociated. Category pickers with a caption are now named by it, on the trigger, the panel
  and the mobile modal.
- [ ] **Reopening the chooser cancels a pending pick.** A row that picks asynchronously (a
  suggestion request, for example) is cancelled when the list reopens, by a later pick, or when
  the control goes away. The legacy chooser applied the result unless the value had changed.

**Tags** (recorded 2026-10-29)

- [ ] **A created tag is shown as the server will store it.** The create row and pasted names
  used to keep emoji, symbols and zero-width characters, and cut long names in UTF-16 units, so
  "Create rock🎸" saved `rock`. Both controls now clean names exactly as the server does, in
  select-kit too (`tests/fixtures/tag-clean-parity.json`).
- [ ] **The breadcrumb tag drop names what it filters.** With nothing filtered it shows "tags"
  as a placeholder and is named "Filter by: tags"; with a tag it reads "Filter by: tags, rock",
  where select-kit read "Filter by: rock". The intersection drop is named the same. Customizations
  reach the drops through `breadcrumb-tag` and `breadcrumb-tag-intersection`.
- [ ] **Sorting alphabetically keeps an exact match first.** With `tags_sort_alphabetically` on,
  the client re-sorted the server's results by name, so typing "rock" could list "alpha-rock"
  above "rock". The tag typed in full now stays first, as the server ranks it, in select-kit too.

**Texts** (recorded 2026-10-30)

- [ ] **`""` means no text.** An empty text at any layer now leaves its place out (no
  placeholder, no empty status, no announcement). Before, an empty argument fell back on the
  default. Required texts, such as names and button labels, still fall back.
- [ ] **The tag requirement moved into the field.** The line DSelect drew under the tag picker
  ("Select at least 2 tags") is gone; select-kit never had it. The placeholder says it instead:
  the required tag group, then the minimum, then "Optional tags…". With tags held, the field
  after the chips keeps saying what is missing ("Select 1 more tag from 'Genre'…"), then "Add more
  tags…". The mobile modal's field says the same. The closed mobile trigger still shows only the
  chips or the count.
- [ ] **Multi-selects say "Add…" after their chips** while another item can be added, and nothing
  at the maximum or while disabled.
- [ ] **The tag panel's minimum line reads as progress** ("1 of 2 required tags selected"). It is
  spoken after each add or remove below the minimum, since its text changes.
- [ ] **Known gap: the required group can be stale.** The group comes from the server's answer to
  a blank search, so it is unknown before the list first opens, and stale after the value or the
  composer category changes while the list is closed. The placeholder then falls back to the
  minimum or the prompt.

## Tag call sites

Tag pickers follow the category rule. A caption that has, or can take, an id is passed as
`@ariaLabelledBy`: preferences, group tag settings, the tag group form, move to topic, chat to
topic and watched words (whose `<label for>` named nothing). FormKit fields and containers pass
their title as the `ariaLabel` text, the site setting and schema controls their `@label`, and the
automation tags field its label, which has no id. The composer, topic edit, the review queue's
tag field, the breadcrumb drops and the templates filter have no caption and keep the recipe
default. The tag settings title drop and advanced search keep the names they had, because they
say more than the caption beside them.

## Category call sites

Category storage fields branch to `DSelectCategory` while `enable_new_select_controls` is on.
Former single choosers pass `@emit="ids"` and `@permission="create"`; advanced search and the
parent-category field pass `@permission="see"`. Former selectors pass `@multiple={{true}}` and
keep emitting category records, and their blocked categories become `@exclude` ids, minus the
list's own held categories. Empty-value text is a translated
`@placeholder`; a field keeps a selectable none row only where the legacy chooser inserted one.

Breadcrumb levels use `DSelectCategoryFilter`, which reads each level through the shared search;
the `@categories` a page passes to `BreadCrumbs` only shapes the legacy drop. The caller routes
category and shortcut picks, and keeps the tag and the editing tab. Each new-control level is keyed by its parent id, because lazy loading can replace the
records backing a level while its list is open.

A call site whose caption has an id passes it as `@ariaLabelledBy`. FormKit custom fields pass
`@ariaLabel={{field.title}}`. The site setting and schema field controls receive their caption's
text as `@label` and pass it on as `@ariaLabel`: the setting heading also holds a history link,
and the schema label has no id.
Pickers with no caption are named "Category", or "Categories" when they can hold more than one;
the placeholder is no longer the name.

The parent-category field drops its caret icon options and the report category filter drops
`filterable`; the recipe has no arguments for them.

The composer and topic-edit choosers take `@identifier` (`composer-category`,
`topic-edit-category`) and an `@instanceContext` carrying the composer model, or the topic and its
buffered state, so customizations can target them through `select-customizations`. A row that
picks asynchronously closes the list and runs `control.update`; a later pick, reopening the list
or destroying the control aborts its signal.

The migrated-module reporting set now includes the category chooser, selector, multiple selector,
advanced-search chooser, category drop with its header and more collection, category row and
selected category choice.

## Porting lessons

Mistakes made porting the tag family and its customizations, kept so the next families avoid
them. Recorded 2026-10-23.

Before writing or reviewing a recipe, use the skill at `.skills/discourse-select-recipes`: it
holds the survey to do first, the red flags and the review gate that these lessons led to.

- **Port the intent, not the shape.** The AI tag suggester was first ported as select-kit had it:
  `idle`/`loading`/`results` modes, the request fired from a row's click handler, a fake
  "loading" row, and `reload()` calls around the request. DSelect's customization points already
  own that lifecycle. Remote work belongs in `spec.load`: a pending loader shows the skeleton, its
  `signal` cancels a superseded request, and a rejection gets the error state with retry. A
  toggle row only flips a flag and calls `control.reload()`. `content` adds rows, `options`
  presents (`loadingStatus` and the `loadingLabel` text name a slow load). The rewrite needed two state values instead of a
  state machine.
- **Never stand in for a pending load with rows.** A fake loading row hides the real loading
  state and races it. If the list is waiting, its loader is pending.
- **Do not collapse the list before the skeleton arrives.** The skeleton mirrors the rows on
  screen when a reload starts, so a customization that drops rows on click shrinks the panel and
  then sizes the skeleton to the shrunk list. Swap a row in place instead of removing it.
- **Refilter in `content`, not by reloading.** Hiding rows that depend on the selection (held
  tags leaving a suggestion list) is a `content` filter on tracked state, which re-runs on its
  own when the selection changes. A `change` middleware that reloads after every pick re-runs
  the loader for nothing, and asks the server again unless the results are cached.
- **Read the response shape from the endpoint.** The suggester port dropped the endpoint's root
  key (`{ assistant: [...] }`) in both paths, and every suggestion request then read as empty.
  Check the controller and the other callers, not the old code's variable names.
- **Assert what only the feature can produce.** The specs that missed that regression picked a
  tag that the default list also offered, so they passed with no suggestions at all. Assert the
  state the feature alone creates (here, the "Suggestions" header row).
- **A recipe that forwards a block forwards its presence too.** A forwarded named block always
  counts as passed, so pass `@suppressFooter={{not (has-block "footer")}}` with a forwarded
  `:footer` (README, Recipes).
- **select-kit row CSS does not fit DSelect rows.** Plugin styles written for select-kit's
  two-child rows (`row-reverse` with `space-between`) misplace content in DSelect's rows. Check
  plugin and theme row styles against a rendered DSelect row, and see the theme CSS audit above
  for the root-is-trigger and portaled-panel traps.
- **Compare against the old component's CSS before calling a port done.** The tag drop lost its
  content-sized panel, its trigger states and its count layout until select-kit's styles were read
  side by side with the new ones.

Added while porting the category family, 2026-10-26:

- **Measure at the scale the family has to serve.** A category chooser passed every behaviour test
  while taking 7 to 9 seconds to open with 10,000 categories, because no test loaded that many.
  Put the target size into a measured gate before the port starts. In rendering tests every row
  a source returns is mounted (virtualization is off), so such a bench measures returned rows,
  not the window.
- **Port customizations to the new kind.** `forKind` matches only a select's `@kind`, never its
  `@legacyKind`; the legacy name exists for the deprecated bridge and the legacy classes. A
  customization written against `forKind("category-chooser")` reaches nothing.
- **Port behaviour, do not invent it.** The suggestion port first cancelled its request whenever
  focus or a click left the picker, which the old component never did, so clicking into the
  composer body silently dropped the suggestion. Cancellation now follows the update scope: a
  later pick, reopening the list or destroying the control.
- **Guard arguments built from records that may not exist yet.** `@exclude={{array @category.id}}`
  on a new category passes `[undefined]`, which reaches the server as `NaN` among the excluded
  ids.
- **Check widths, not only classes.** The DSelect root keeps the legacy class, so call-site layout
  rules such as `.category-chooser { width: 100% }` still apply, but `.select-kit.*` defaults do
  not: select-kit's choosers and multi-selects were 300px wide, and a DSelect fills its container.
  Find the layouts that relied on the old default.
- **A new module needs a full build before plugins can import it.** A devserver started before a
  recipe existed cannot serve it to plugin bundles; restart the devserver instead of adding a
  loader shim.

Added after reviewing the category recipes, 2026-10-27:

- **Survey the engine, the model and the ui-kit helpers before writing recipe code, and ask
  before adding what seems missing.** The first category recipes paged, sized and de-duplicated
  rows by hand, wrapped `Category`'s own search and lookups in a `lib/` module, flipped
  `@multiple`'s default, toggled `@debounce`, drew their own caret and called a badge helper's
  internals. Every one of those already existed. The rework removed them; the skill above lists
  them as red flags.
- **A call-site quirk belongs at the call site.** The preference lists passed their own held
  categories as `@exclude`, and the recipe grew a "held stays offered" exception and a reload
  key to match. Each list now passes only the other lists' categories.
- **Stub endpoints as they answer.** A `/categories/find` stub that ignored the requested ids
  made a correct lookup remove a category from the site and fail far from the cause.

## Verification

- **Test model:** a family's tests branch with the flag. Its existing tests keep driving
  select-kit through `selectKit()` and `SelectKit`, pinned off with `with_select_controls(false)`,
  and are deleted with the legacy branch. Its port adds flag-on tests in final form on DSelect's own
  helpers: `dSelect()` and `assert.dSelect()` in QUnit, `UiKit::DSelect.at` in system specs.
  Both sides are written from one list of the family's call-site scenarios. System specs pin with
  `with_select_controls`, which holds after promotion
  (`spec/integrity/select_controls_pin_spec.rb`). QUnit uses raw defaults with no promotion, so
  off is the default and on is `needs.settings({ enable_new_select_controls: true })` or the
  site-settings service. Specs and page objects that query select-kit internals directly move
  with their family.
- **Per family:** call-site tests and system specs in both modes that assert which implementation
  rendered; state round trips across modes; legacy and new controls mixed on one page; member,
  staff and anonymous paths; Foundation and Horizon, light and dark, mobile (DSelect opens a
  DModal) and screen readers; `script/check_strict_types` and `pnpm lint:types` clean.
- **`modifyClass` deprecation:** unit tests cover the migrated-set gate, the flag, exact class vs
  subclass, nested names, static patches, plugin and theme attribution, and throw-after-patch per
  environment. Each family adds a boot test with a real plugin patch when it joins.
- **Before beta:** the customer repos' own specs pass with the flag on.
