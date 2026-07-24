---
name: discourse-upcoming-changes-authoring
description: Use when modifying, debugging, or extending the upcoming changes framework code and system itself.
---

# Upcoming Changes Framework — Authoring Guide

This skill is for working on the upcoming changes framework itself — the internal machinery that powers feature flag rollout in Discourse. For *adding a new feature flag* using the framework, see the `discourse-upcoming-changes` skill instead.

## Architecture Overview

The upcoming changes system has three layers: a **Ruby core** that manages state and business logic, a **services layer** that orchestrates tracking/notifications/toggling, and an **Ember frontend** that renders the admin UI and applies per-user overrides.

### Ruby Core

**`lib/upcoming_changes.rb`** — The central module. All business logic for resolving values, checking user eligibility, caching, and image handling lives here.

Key methods to understand:

- `enabled?(setting_name)` — Determines the *effective* value of a change. This is where auto-promotion logic lives: if a setting's status meets/exceeds `promote_upcoming_changes_on_status`, it resolves to `true` even if the DB default is `false`. Permanent settings always resolve to `true` (admins can't disable them). It returns `false` outright when the owning plugin is not configurable, or — for plugin-owned changes, unless they opt out with `requires_plugin_enabled: false` — when the owning plugin is disabled. Both take precedence over the above. See [Requiring the Owning Plugin](#requiring-the-owning-plugin).
- `enabled_for_user?(setting_name, user)` — The primary access check. Considers: the resolved value from `enabled?`, group restrictions, anonymous users (only get access if no group restrictions).
- `stats_for_user(user:, acting_guardian:)` — Returns per-change status for a user including *why* they have/don't have access (the `user_enabled_reasons` enum).
- `current_statuses` / `permanent_upcoming_changes` — Cached lookups keyed by git version (one-time cost per deploy). Cleared by `clear_caches!` and automatically when `TrackStatusChanges` detects changes.
- `settings_hidden_while_enabled` — Returns the set of *other* site setting names that should be hidden from admins because an enabled change declares them in its `hide_settings:` metadata. Computed live (not toggled at opt-in time) so it tracks both opt-in paths and is multisite-safe. See [Hiding Settings While Enabled](#hiding-settings-while-enabled) below.


**`UpcomingChanges::ConditionalDisplay`** (defined inside `lib/upcoming_changes.rb`) — Hides individual upcoming changes from the admin UI when they don't make sense in the current context (e.g. a Horizon-related change on a site without Horizon installed). Core gates can define a `should_display_<upcoming_change_name>?` class method on it; plugin-owned upcoming changes should use `Plugin::Instance#register_upcoming_change_conditional_display`. If no rule is defined, the change is always displayed. See [Conditional Display](#conditional-display) below.

**`app/models/upcoming_change_event.rb`** — Audit trail. Every lifecycle event (added, removed, status change, manual toggle, admin notification) is recorded here. Has unique indexes to prevent duplicate events of specific types per change.

**`lib/site_setting_extension.rb`** — Where `upcoming_change:` metadata in `site_settings.yml` gets parsed. When a setting is registered with this metadata, it stores the parsed result in `@upcoming_change_metadata` and defines a `{name}_groups_map` method. The `impact` string is split into `impact_type` and `impact_role`. The `hide_settings:` array (if present) is normalized to an array of symbols. Also handles `upcoming_change_default_override:` metadata — see [Default Overrides](#default-overrides) below.

**`lib/site_settings/hidden_provider.rb`** — `HiddenProvider#all` (the source of `SiteSetting.hidden_settings`) unions in `UpcomingChanges.settings_hidden_while_enabled` before applying the `:hidden_site_settings` plugin modifier, so plugins can still explicitly un-hide a setting. The union is skipped entirely when no change opts in, to avoid allocating a new Set on every read. See [Hiding Settings While Enabled](#hiding-settings-while-enabled) below.

**`lib/site_settings/defaults_provider.rb`** — Manages the default values for all settings, including upcoming change default overrides. Tracks which overrides are active via `@active_upcoming_change_overrides` and applies them when resolving defaults. Provides `upcoming_change_override_metadata` for the frontend to display warnings about changed defaults.

**`app/models/site_setting_group.rb`** — Stores group restrictions for settings. Group IDs are pipe-separated strings (`"1|2|3"`). The `setting_group_ids` class method returns a hash used for in-memory caching.

### Services Layer

All services use `Service::Base`. They're organized under `app/services/upcoming_changes/`:

| Service | Purpose |
|---------|---------|
| `List` | Admin-only, fetches all changes with metadata, group data, and images. Filters out changes whose `ConditionalDisplay.should_display?` returns false. |
| `Toggle` | Admin enable/disable — updates SiteSetting, clears groups when neither `staff` nor `specific_groups` is in `allow_enabled_for`, validates the requested target against `allow_enabled_for`, logs staff action, fires DiscourseEvent |
| `Track` | Orchestrator called by `CheckUpcomingChanges` — delegates to three action sub-services. Does not notify admins about available changes — that happens once a week in `Jobs::NotifyAdminsOfAvailableUpcomingChanges`. |
| `TrackAddedChanges` | Compares current settings against event history, creates `added` events |
| `TrackRemovedChanges` | Creates `removed` events for settings no longer present |
| `TrackStatusChanges` | Detects status changes in metadata, creates events, clears caches |
| `NotifyPromotions` | Iterates all changes and calls `NotifyPromotion` for each |
| `NotifyPromotion` | Handles one promotion — checks policies, merges notifications, fires events |
| `NotificationDataMerger` | Consolidates multiple change notifications into one to avoid spam (used by both the weekly availability job and `NotifyPromotion`) |

**`SiteSetting::UpsertGroups`** — Manages group assignments for settings (upserts `SiteSettingGroup`, refreshes caches, notifies clients).

### Scheduled Jobs

**`app/jobs/scheduled/check_upcoming_changes.rb`** — Runs every 20 minutes inside a `DistributedMutex`. Calls `Track` (to log `added`/`removed`/`status_changed` events) then `NotifyPromotions` (which sends auto-promotion notifications immediately). Supports verbose logging via the `upcoming_change_verbose_logging` setting. **Does not** send "change available" notifications to admins — that is the weekly job below.

**`app/jobs/scheduled/notify_admins_of_available_upcoming_changes.rb`** — Runs once a week. Collects every change that was either `added` at, or status-changed *to*, `promote_upcoming_changes_on_status - 1` within the last week and has no prior `admins_notified_available_change` or `admins_notified_automatic_promotion` event. Notifies all admins who have `enable_upcoming_change_available_notifications` enabled, consolidating into a single notification per admin via `NotificationDataMerger` (merging with existing unread notifications if present, otherwise creating one new notification per admin covering all newly-available changes). Gated on `UpcomingChanges.should_notify_admins?` so new sites are suppressed. Writes `admins_notified_available_change` events and a `log_upcoming_change_available` staff log entry per change.

### Frontend

**Admin page** — `admin/templates/admin-config/upcoming-changes.gjs` renders the page header, `admin/components/admin-config-areas/upcoming-changes.gjs` is the container with filtering, and `admin/components/admin-config-areas/upcoming-change-item.gjs` renders each row.

**Key frontend patterns:**
- Filtering by status, impact type, impact role, and enabled/disabled state via `DFilterControls`
- Group selection uses a multi-select dropdown with debounced API saves
- Toast notifications for all toggle/group changes
- Lightbox integration for preview images

**Site settings service** (`app/services/site-settings.js`) — Loads upcoming changes from `PreloadStore`, applies them as overrides to site settings, and stores them in `settings.currentUserUpcomingChanges`.

**Body CSS classes** — `app/controllers/application.js` generates `uc-{dasherized-key}` classes on `<body>` for each enabled upcoming change that opts in via `body_class: true`, allowing CSS-based feature gating. The controller intersects `siteSettings.currentUserUpcomingChanges` (enabled-for-this-user changes) with `site.upcoming_changes_with_css` (changes that opted into CSS) — a change must be in both to get a body class. The opt-in list comes from `SiteSerializer#upcoming_changes_with_css`, which returns the change names whose metadata has `body_class: true`. See [CSS Opt-In](#css-opt-in) below.

**Notifications** — Two notification types (`upcoming-change-available`, `upcoming-change-automatically-promoted`) handle singular/dual/many change descriptions and link to the admin page with filter params.

**Sidebar** — Badge notification dot appears on the upcoming changes link when `currentUser.hasNewUpcomingChanges` is true.

**MessageBus** — Subscribes to `/client_settings` and updates both `siteSettings` and `currentUserUpcomingChanges` in real time.

### Controller

**`admin/config/upcoming_changes_controller.rb`** — Three endpoints:
- `GET index` — List changes (with `filter_statuses` param)
- `PUT update_groups` — Set group restrictions for a setting
- `PUT toggle_change` — Enable/disable a setting

### Problem Check

**`app/services/problem_check/upcoming_change_stable_opted_out.rb`** — Warns admins hourly if they've opted out of a stable/permanent change.

### Default Overrides

Upcoming changes can override the default value of a *different* site setting when enabled. This allows feature rollouts to change related setting defaults without breaking admin customizations.

#### Metadata Format

A setting declares a default override with the `upcoming_change_default_override` key in `config/site_settings.yml`:

```yaml
# The upcoming change setting (the "trigger")
increase_suggested_topics_max_days_old_default:
  default: false
  type: bool
  upcoming_change:
    status: experimental
    impact: "site_setting_default,all_members"

# The setting whose default changes (the "target")
suggested_topics_max_days_old:
  default: 365
  type: integer
  upcoming_change_default_override:
    upcoming_change: increase_suggested_topics_max_days_old_default
    new_default: 1000
```

When `increase_suggested_topics_max_days_old_default` is enabled (either manually by admin or via auto-promotion), the default value of `suggested_topics_max_days_old` changes from `365` to `1000`. The `impact` field on the trigger setting should include `site_setting_default` as its `impact_type`.

#### How It Works

1. **Registration** — `lib/site_setting_extension.rb` parses `upcoming_change_default_override` during setting registration and stores it in `upcoming_change_default_overrides` (a hash keyed by setting name).

2. **Activation** — During `SiteSetting.refresh!`, each override is checked: if `UpcomingChanges.enabled?(override[:upcoming_change])` returns true, the override is activated via `defaults.activate_upcoming_change_override`. The setting's current value is updated to `new_default` **only if the admin has not manually modified it**.

3. **Default resolution** — `DefaultsProvider#all` applies active overrides when resolving defaults, so code reading `SiteSetting.defaults[:setting_name]` gets the overridden value.

4. **Frontend display** — `DefaultsProvider#upcoming_change_override_metadata` returns `{ old_default:, new_default:, change_setting_name: }` for active overrides. The site settings UI (`admin/components/site-setting.gjs`) shows a warning linking to the upcoming changes page.

#### Key Behaviors

- **Non-destructive**: If an admin has manually set a custom value for the target setting, the override does not apply — it only affects the default.
- **Reversible**: Disabling the upcoming change deactivates the override and restores the original default.
- **Default-locale only**: Overrides currently only apply on the default locale.

### Conditional Display

Some upcoming changes only make sense to show admins under certain conditions — for example, a Horizon-themed change is irrelevant if Horizon isn't installed, or a change might only apply when another setting is enabled. `UpcomingChanges::ConditionalDisplay` (in `lib/upcoming_changes.rb`) lets the framework hide a change from the admin UI without removing it from `site_settings.yml`.

#### How It Works

1. **Filtering** — `UpcomingChanges::List#fetch_upcoming_changes` calls `UpcomingChanges::ConditionalDisplay.should_display?(setting_name)` on every change after the status filter, before group/image enrichment. Changes that return `false` are dropped from the result entirely.
2. **Resolution** — `should_display?` first hides the change outright if its owning plugin is not configurable (`owning_plugin_configurable?`), or if it is plugin-owned and the owning plugin is disabled (`owning_plugin_enabled?`) — unless the change opts out with `requires_plugin_enabled: false`. Then it checks for a class method named `should_display_<upcoming_change_name>?` on `ConditionalDisplay`. If defined, its return value is used. Otherwise it evaluates enabled plugin callbacks registered for that setting. If no method or callback is defined, the change is always displayed (returns `true`).
3. **Definition site** — Core gates can live directly on `ConditionalDisplay`, typically next to the relevant subsystem's code. Plugin gates should be registered from the plugin initializer via `register_upcoming_change_conditional_display(:setting_name) { ... }` so disabled plugins are filtered by `DiscoursePluginRegistry`.

#### Key Behaviors

- **Display-only, with one exception**: A gate normally affects whether the change appears in the admin UI, not whether it's enabled — `enabled?` / `enabled_for_user?` still resolve normally, so code paths gated on the change continue to work. The exception is the owning-plugin checks, which `enabled?` consults too (see below).
- **Don't express the owning-plugin gate with a conditional display callback**: it's already the default for plugin-owned changes, and a callback couldn't express it anyway — `DiscoursePluginRegistry` filters callbacks from disabled plugins, so it would never run in the only case that matters. See [Requiring the Owning Plugin](#requiring-the-owning-plugin).
- **N+1 by design**: `should_display?` is called once per change in the loop. If a gating method does expensive work (DB queries, plugin lookups), memoize inside the method to avoid repeated cost.
- **Notifications are gated too**: Beyond the `List` service, `NotifyAdminsOfAvailableUpcomingChanges` and `NotifyPromotion` also consult `should_display?`, so a hidden change is not notified about. `TrackAddedChanges` / `TrackRemovedChanges` do not — the audit trail records every change regardless. A gate should still reflect a long-lived condition (plugin missing, theme not installed) rather than transient state.

### Requiring the Owning Plugin

A plugin-owned change that gates a feature *inside* its plugin is useless while that plugin is disabled — the plugin's code isn't running, so the admin is being pitched (and notified about) a toggle that does nothing. This is the **default** for every plugin-owned change: no metadata is needed to get it.

```yaml
enable_your_plugin_feature:
  default: false
  client: true
  hidden: true
  upcoming_change:
    status: experimental
    impact: feature,all_members
    # requires_plugin_enabled defaults to true for plugin-owned changes -- nothing to add.
```

While the plugin is off, `UpcomingChanges.owning_plugin_enabled?` returns false, which both hides the change (`should_display?`) and stops it resolving (`enabled?`), so its `hide_settings` and default overrides don't apply either. The admin's opt-in stays in the database and resumes when they re-enable the plugin.

#### Opting out

Plenty of plugin-owned changes are the *opposite*: they exist to get the plugin adopted, and only make sense while it is disabled. Leaving one gated makes it unreachable — it would be hidden from exactly the sites it targets. These must opt out with `requires_plugin_enabled: false`:

```yaml
enable_your_plugin_feature:
  default: false
  client: true
  hidden: true
  upcoming_change:
    status: experimental
    impact: feature,all_members
    requires_plugin_enabled: false
```

Current examples, all of which set `requires_plugin_enabled: false`:

| Change | Why it must work with the plugin off |
|---|---|
| `enable_events_category_type_setup` (calendar), `enable_support_category_type_setup` (solved), `enable_ideas_category_type_setup` (topic-voting) | Offers a category type whose `enable_plugin` hook turns the plugin on when an admin picks it. Core registers category types *without* the plugin enabled — see `Categories::Types::Base#enable_plugin`. |
| `enable_discourse_reactions_by_default` (reactions) | An `upcoming_change_default_override` that flips `discourse_reactions_enabled` from `false` to `true`. Gating it on the plugin being enabled means it can never fire. |
| `enable_discourse_workflows` (workflows) | *Is* the plugin's `enabled_site_setting`. That row is how an admin opts into the plugin at all, so it *must* opt out — otherwise the default gate would gate the change on itself. |

Rule of thumb: if the change's purpose is *"try this feature we added to the plugin you already run"*, leave it gated (the default). If its purpose is *"start using this plugin"*, opt out with `false`.

#### Guardrails

The integrity spec (`spec/integrity/upcoming_change_metadata_spec.rb`) enforces that `requires_plugin_enabled`, when present, is a boolean and is only set on plugin-owned changes. It also **requires** a change that is its plugin's own `enabled_site_setting` to set `requires_plugin_enabled: false` — leaving the default gate on it would be self-gating and would recurse (`Plugin::Instance#enabled?` reads the setting, which resolves back through `enabled?`). `owning_plugin_enabled?` also guards against the recursion at runtime, so a mistake surfaces as a hidden change rather than a stack overflow. The spec derives ownership and the plugin's `enabled_site_setting` from the file path and `plugin.rb`, so it holds regardless of which plugins are loaded in the run.

### CSS Opt-In

A change can opt into having a `uc-{dasherized-key}` class added to `<body>` when it is enabled for the current user, so stylesheets can gate visuals on the change. This is **opt-in** via the `body_class: true` metadata key — body classes are *not* emitted for every enabled change, only those that ask for them. This keeps the body class list small and intentional, and avoids leaking the names of unrelated (non-visual) changes into the DOM.

```yaml
enable_your_feature_name:
  default: false
  client: true
  hidden: true
  upcoming_change:
    status: experimental
    impact: feature,all_members
    body_class: true
```

#### How It Works

1. **Parsing** — `lib/site_setting_extension.rb` reads `body_class` from the `upcoming_change:` metadata and stores it (defaulting to `nil`/falsey) in `upcoming_change_metadata`.
2. **Serialization** — `SiteSerializer#upcoming_changes_with_css` filters `SiteSetting.upcoming_change_site_settings` down to the change names whose metadata has `body_class` truthy, and exposes them to the frontend as `site.upcoming_changes_with_css`.
3. **Body class generation** — `app/controllers/application.js` iterates `siteSettings.currentUserUpcomingChanges` and pushes a `uc-{dasherize(key)}` class only when both the setting is truthy for the user **and** `site.upcoming_changes_with_css.includes(key)`. A change must be enabled *and* opted-in to get a class.

#### Key Behaviors

- **Opt-in only**: Omitting `body_class` (or setting it `false`) means no body class — the default. Add it only when you actually have CSS keyed on `uc-{name}`.
- **Always wrap in `:where()`**: Style the class as `:where(.uc-{name})`, never a bare `.uc-{name}`, so the transitional class adds zero specificity and stays safe to unwrap and delete later — the `discourse/uc-classes-in-where` stylelint rule enforces this.
- **Enabled-for-user gated**: The class only appears for users the change is enabled for (via `currentUserUpcomingChanges`), not globally. Anonymous/ineligible users won't get it.
- **Integrity-checked**: `body_class` is in the integrity spec's `allowed_keys` and must be a boolean — see [Mocking Metadata](#mocking-metadata) for how to set it in tests.

### Permanent Soon Warning

Once a change reaches `stable` status, the admin page shows a warning on its row: "This change will become permanent soon. You will no longer be able to opt-out." This is **opt-out** via the `permanent_warning:` metadata key — every stable change shows the warning unless it explicitly sets `permanent_warning: false`.

```yaml
enable_your_feature_name:
  default: false
  client: true
  hidden: true
  upcoming_change:
    status: "stable"
    impact: "site_setting_default,all_members"
    permanent_warning: false
```

#### How It Works

1. **Parsing** — `lib/site_setting_extension.rb` reads `permanent_warning` from the `upcoming_change:` metadata and normalizes it to a boolean (`!= false`, so an omitted key becomes `true`) in `upcoming_change_metadata`.
2. **Rendering** — `UpcomingChangeItem#showPermanentSoonNotice` (`admin/components/admin-config-areas/upcoming-change-item.gjs`) renders the notice when `status === "stable"` and `permanent_warning !== false`. The `!== false` comparison (rather than a truthy check) means metadata that omits the key — including hashes built by `mock_upcoming_change_metadata` — still shows the notice.

#### Key Behaviors

- **Opt-out, not opt-in**: The default is to warn. Suppress it only when the warning would be misleading — the usual case is a `site_setting_default` change, where becoming permanent just changes another setting's default and the admin can still set that setting to whatever they want.
- **Stable-only**: The key has no effect below `stable`, and `permanent` changes don't show the notice either (they already are permanent).
- **Independent of `impact_type`**: Before this key existed, the notice was implicitly suppressed for every `site_setting_default` change. That coupling is gone — impact type no longer affects the notice.
- **Integrity-checked**: `permanent_warning` is in the integrity spec's `allowed_keys` and must be a boolean.

### Hiding Settings While Enabled

A change can declare other site settings that should be hidden from admins while it is enabled, via the optional `hide_settings:` metadata key. This is for *legacy* settings that stop making sense once the change replaces them — they disappear from the admin UI rather than being deleted, and reappear if the change is disabled.

```yaml
enable_your_feature_name:
  default: false
  client: true
  hidden: true
  upcoming_change:
    status: experimental
    impact: feature,all_members
    hide_settings:
      - legacy_setting_one
      - legacy_setting_two
```

#### How It Works

1. **Parsing** — `lib/site_setting_extension.rb` reads `hide_settings` from the `upcoming_change:` metadata, normalizes it to an array of symbols, and stores it in `upcoming_change_metadata`.
2. **Live computation** — `UpcomingChanges.settings_hidden_while_enabled` scans the metadata and, for each change that declares `hide_settings`, calls `enabled?(change_name)` and concatenates the declared settings when the change is on. `enabled?` is only called for the (usually zero) changes that declare `hide_settings`, so the common case is a cheap metadata scan with no DB hit; it returns `[]` immediately when no metadata exists.
3. **Application** — `SiteSettings::HiddenProvider#all` unions the result into the hidden set (before the `:hidden_site_settings` modifier) on every `SiteSetting.hidden_settings` read.

#### Key Behaviors

- **Computed live, not toggled**: The hidden set is recomputed per request rather than flipped imperatively at opt-in time. This means it automatically tracks *both* opt-in paths — manual admin enable and auto-promotion — and stays correct if the change is later disabled.
- **Multisite-safe**: The metadata (and thus the declared `hide_settings`) is process-global, but `enabled?` resolves per-site. A setting is only hidden for sites that have actually opted into the change.
- **Plugins can still un-hide**: The union happens *before* the `:hidden_site_settings` modifier, so a plugin can explicitly remove a setting from the hidden set via that modifier.
- **Integrity-checked**: `hide_settings` is in the integrity spec's `allowed_keys`. When present it must be an array, and every referenced name must be a real site setting (`SiteSetting.respond_to?`) — typos fail the spec. See [Mocking Metadata](#mocking-metadata) for how to set it in tests.

## Key Design Decisions

### Caching Strategy

The `current_statuses` and `permanent_upcoming_changes` caches are keyed by git version (`Discourse.git_version`). This means they're naturally invalidated on every deploy — no TTL needed. Within a deploy, `TrackStatusChanges` calls `clear_caches!` when it detects metadata changes. Always call `clear_caches!` in tests after modifying metadata.

### Auto-Promotion

The `resolved_value` method is the single source of truth for whether a setting is "on." Auto-promotion happens implicitly: when a setting's status meets the threshold, `resolved_value` returns `true` regardless of the DB value. The DB value only changes when an admin explicitly toggles. This separation means promotion is reversible by the admin without losing the original opt-in/opt-out state.

### Notification Merging

When multiple changes need notifications, `NotificationDataMerger` consolidates them into a single notification per admin. It finds existing unread notifications and merges the change names array. The frontend notification types handle singular ("Feature X"), dual ("Feature X and Feature Y"), and many ("Feature X and 2 others") display.

For "change available" notifications specifically, merging also happens across the *batch* processed by the weekly `NotifyAdminsOfAvailableUpcomingChanges` job — for admins without an existing unread notification, the job builds a single new notification per admin that lists every newly-available change in that run, rather than emitting one notification per change.

### New Site Notification Suppression

Notifications for "change available" and "promoted" are skipped on new sites (determined by `Migration::Helpers.new_site?` in `lib/migration/helpers.rb` — a site is "new" if its first schema migration was less than 1 hour ago). Both the weekly `NotifyAdminsOfAvailableUpcomingChanges` job and the `NotifyPromotion` service guard on `UpcomingChanges.should_notify_admins?`. This prevents freshly provisioned sites from being flooded with notifications for every existing upcoming change on their first run. The tracking/detection steps still execute — only the notification delivery is suppressed.

### Group-Based Access

Group restrictions use a separate `SiteSettingGroup` model rather than storing groups on the setting itself. This allows the caching layer (`site_setting_group_ids`) to work independently. Group IDs are pipe-separated in the DB for efficient single-row storage.

The `allow_enabled_for` metadata key on an upcoming change restricts which "Enabled for" dropdown options the admin sees. It accepts an array of any subset of `[everyone, staff, specific_groups]`; the `No one` option is always present and cannot be removed. When the key is omitted, all four options are shown (the permissive default). Rule: if `everyone` is present it must be the only value — `everyone` cannot combine with `staff` or `specific_groups`. The integrity spec enforces these rules. Server-side enforcement lives in `UpcomingChanges::Toggle` (validates the target when no groups are configured) and `SiteSetting::UpsertGroups` (validates group selection: a `[staff]`-only selection needs `staff` allowed; any other selection needs `specific_groups` allowed). When neither `staff` nor `specific_groups` is in the allow list, `Toggle` also clears any stale `SiteSettingGroup` records.

**Auto-promoted display:** When `allow_enabled_for` excludes `:everyone` and a change is enabled without an explicit admin selection (typically because it reached the promotion threshold), `enabled_for_with_groups` returns the broadest allowed display target — the staff group name if `:staff` is permitted, otherwise `"groups"`. This is display-only; `enabled_for_user?` is unchanged and still treats the change as on for all users until the admin scopes it via the dropdown.

### Event Idempotency

`UpcomingChangeEvent` has unique indexes on specific event type + change name combinations. This prevents duplicate `added`, `removed`, or notification events even if the job runs multiple times. Always check for existing events before creating new ones in service code.

## Common Modification Scenarios

### Adding a New Status

1. Add the status and its numeric value to `UpcomingChanges.statuses` in `lib/upcoming_changes.rb`
2. The numeric ordering determines hierarchy — `meets_or_exceeds_status?` uses these values
3. Update `previous_status` mapping if the new status fits in the progression
4. Add status badge styling in `app/assets/stylesheets/admin/upcoming-changes.scss` (`.upcoming-change__badge.--status-{name}`)
5. Add translations for the status label

### Adding a New Event Type

1. Add the enum value to `UpcomingChangeEvent` (`app/models/upcoming_change_event.rb`)
2. If the event should be unique per change, add a unique index in a migration
3. Create or update the relevant service to emit the event

### Modifying the Admin UI

The three main components to know:
- **Container** (`upcoming-changes.gjs`) — Filtering logic and data management
- **Item** (`upcoming-change-item.gjs`) — Individual change row rendering and interactions
- **User view** (`admin-user-upcoming-changes.gjs`) — Read-only per-user view

State is managed via `trackedObject` for reactivity. API calls go through `ajax()` directly in the item component.

### Restricting "Enabled for" options

To constrain which dropdown options an admin can pick for a change, add `allow_enabled_for` to its `upcoming_change:` metadata:

```yaml
my_upcoming_change_setting:
  default: false
  client: true
  hidden: true
  upcoming_change:
    status: experimental
    impact: feature,all_members
    allow_enabled_for:
      - staff
      - specific_groups
```

Valid value sets:

| `allow_enabled_for` | Dropdown options shown |
|---|---|
| *(omitted)* | No one, Everyone, Staff, Specific group(s) |
| `[everyone]` | No one, Everyone |
| `[staff]` | No one, Staff |
| `[specific_groups]` | No one, Specific group(s) |
| `[staff, specific_groups]` | No one, Staff, Specific group(s) |

`everyone` cannot be combined with `staff` or `specific_groups` — when present, it must be the only value. `No one` is always available. The integrity spec rejects invalid combinations.

### Adding a Conditional Display Rule

To hide an upcoming change from the admin UI under certain conditions:

1. For plugin-owned changes, register a callback from `plugin.rb`:
   ```ruby
   register_upcoming_change_conditional_display(:enable_plugin_feature) do
     SiteSetting.some_dependency_enabled
   end
   ```
   The condition must be something *other* than the plugin's own `enabled_site_setting` — core already hides changes owned by a disabled plugin, and the registry would filter the callback out anyway.
2. For core changes, reopen `UpcomingChanges::ConditionalDisplay` and define a class method named `should_display_<upcoming_change_name>?` that returns a boolean:
   ```ruby
   module UpcomingChanges
     class ConditionalDisplay
       def self.should_display_enable_horizon_blah?
         Discourse.plugins_by_name["horizon"].present?
       end
     end
   end
   ```
3. Place core gates near the related subsystem so the gate lives with the code that owns the condition.
4. If the check is expensive, memoize inside the method or callback — `List` calls `should_display?` once per change.
5. Multiple plugin callbacks for the same setting are combined with `all?`, so any enabled plugin can hide the change.
6. Test by stubbing the predicate or registering a callback — see [Testing Conditional Display](#testing-conditional-display).

### Adding a Default Override

To make an upcoming change control the default of another setting:

1. Add `upcoming_change_default_override` metadata to the **target** setting in `config/site_settings.yml`:
   ```yaml
   target_setting:
     default: original_value
     upcoming_change_default_override:
       upcoming_change: trigger_setting_name
       new_default: new_value
   ```
2. Ensure the **trigger** setting has `impact: "site_setting_default,..."` in its `upcoming_change:` metadata
3. The override activates automatically when the trigger is enabled — no additional code needed
4. Test with `mock_upcoming_change_default_overrides` — see [Mocking Default Overrides](#mocking-default-overrides)

### Hiding Legacy Settings While a Change Is Enabled

To hide other settings from admins while an upcoming change is enabled (e.g. legacy settings the change replaces):

1. Add a `hide_settings:` array to the change's `upcoming_change:` metadata in `config/site_settings.yml`, listing the setting names to hide:
   ```yaml
   enable_your_feature_name:
     default: false
     client: true
     hidden: true
     upcoming_change:
       status: experimental
       impact: feature,all_members
       hide_settings:
         - legacy_setting_one
   ```
2. The settings are hidden automatically whenever the change is enabled (manual opt-in or auto-promotion) and reappear when it is disabled — no additional code needed.
3. Every name must be a real site setting or the integrity spec fails. See [Hiding Settings While Enabled](#hiding-settings-while-enabled).

### Changing Resolution Logic

All value resolution goes through `resolved_value` in `lib/upcoming_changes.rb`. If you need to change how settings are evaluated (e.g., adding a new override condition), this is the single place to modify. The method checks in order: permanent status, admin manual override, auto-promotion threshold.

## Testing Patterns

### Mocking Metadata

Use the test helper to mock upcoming change metadata — never modify `site_settings.yml` in tests:

```ruby
mock_upcoming_change_metadata(
  {
    enable_some_feature: {
      impact: "feature,all_members",
      status: :experimental,
      impact_type: "feature",
      impact_role: "all_members",
      body_class: true, # optional — opts into the uc-{name} body class
      permanent_warning: false, # optional — suppresses the "becomes permanent soon" notice at stable
      hide_settings: %i[legacy_setting_one], # optional — settings hidden while enabled
    },
  },
)
```

To test `hide_settings`, mock a change with a `hide_settings:` array, then assert the named settings are absent from `SiteSetting.hidden_settings` (or `HiddenProvider#all`) until the change is enabled and present once it is — remember to enable the change (`SiteSetting.<name> = true`) and clean up with `remove_override!` + `UpcomingChanges.clear_caches!`. See `spec/lib/upcoming_changes_spec.rb` (`.settings_hidden_while_enabled`) and `spec/lib/site_settings/hidden_provider_spec.rb`.

To test the CSS opt-in serializer (`SiteSerializer#upcoming_changes_with_css`), mock two changes — one with `body_class: true` and one with `body_class: false` — and assert the serialized array includes the former and excludes the latter. See `spec/serializers/site_serializer_spec.rb`. System coverage for the resulting `uc-{name}` body class lives in `spec/system/member_upcoming_changes_spec.rb`.

### Mocking Default Overrides

Use `mock_upcoming_change_default_overrides` to set up override metadata in tests — never modify `site_settings.yml`:

```ruby
mock_upcoming_change_default_overrides(
  {
    suggested_topics_max_days_old: {
      upcoming_change: :increase_suggested_topics_max_days_old_default,
      new_default: 1000,
    },
  },
)

# Enable the trigger setting and refresh to activate the override
SiteSetting.increase_suggested_topics_max_days_old_default = true
SiteSetting.refresh!

# Now SiteSetting.suggested_topics_max_days_old returns 1000 (the overridden default)
```

To test that the override does NOT apply when the admin has customized the target setting:

```ruby
# Admin sets a custom value before the override activates
SiteSetting.suggested_topics_max_days_old = 730
SiteSetting.increase_suggested_topics_max_days_old_default = true
SiteSetting.refresh!

# Override is not applied — admin's explicit choice is preserved
expect(SiteSetting.suggested_topics_max_days_old).to eq(730)
```

### Testing Conditional Display

For plugin-owned changes, test the registry path:

```ruby
Plugin::Instance
  .new
  .register_upcoming_change_conditional_display(:enable_plugin_feature) { false }
```

For core changes, stub the predicate method directly on `UpcomingChanges::ConditionalDisplay` rather than redefining it — this avoids leaking method definitions across examples:

```ruby
UpcomingChanges::ConditionalDisplay
  .stubs(:should_display_enable_upload_debug_mode?)
  .returns(false)
```

For unit tests of `ConditionalDisplay` itself (where you need to verify dispatch), use `define_singleton_method` in `before` and `remove_method` in `after` to clean up:

```ruby
before do
  UpcomingChanges::ConditionalDisplay.define_singleton_method(
    :should_display_enable_upload_debug_mode?,
  ) { false }
end

after do
  UpcomingChanges::ConditionalDisplay.singleton_class.send(
    :remove_method,
    :should_display_enable_upload_debug_mode?,
  )
end
```

When testing `UpcomingChanges::List`, assert the change is/isn't present in `result.upcoming_changes` by `:setting` key.

### Cache Clearing in Tests

After modifying metadata or settings, call `UpcomingChanges.clear_caches!` to ensure tests see fresh data. The caches are keyed by git version, so they persist across test examples unless explicitly cleared.

### Testing Services

Services follow standard `Service::Base` test patterns — see the `discourse-service-authoring` skill. Use `run_successfully`, `fail_a_policy`, etc.

### System Tests

Page objects live at:
- `spec/system/page_objects/pages/admin_upcoming_changes.rb` — Main page
- `spec/system/page_objects/pages/admin_upcoming_change_item.rb` — Item component

Key page object methods:
- `change_item(setting_name)` — Get an item component by setting name
- `has_change?` / `has_no_change?` — Visibility assertions
- `select_enabled_for(option)` — Toggle the enabled dropdown
- `add_group` / `remove_group` / `save_groups` — Group management
- `has_enabled_for_success_toast?` — Verify success feedback

System tests use `mock_upcoming_change_metadata` in `before` blocks. When revisiting pages to verify persistence, be aware of rate limiting on API calls.

### Testing the Scheduled Job

Use `track_log_messages` to verify job output:

```ruby
track_log_messages do |logger|
  described_class.new.execute({})
  expect(logger.infos.join("\n")).to include("Expected message")
end
```

Set up event history with `UpcomingChangeEvent.create!` and clean up with `delete_all` as needed.

### Multisite Tests

Cache isolation tests live in `spec/multisite/upcoming_changes_spec.rb`. Use `test_multisite_connection("default")` / `test_multisite_connection("second")` blocks and clean up cache keys explicitly per site.

### JavaScript Tests

Notification type tests create notifications with `Notification.create()` and verify `director.description`, `director.linkHref`, and `director.icon`. Test singular, dual, and many-change scenarios plus backward compatibility with old data formats.

## File Reference

| Area | Key Files |
|------|-----------|
| Core module | `lib/upcoming_changes.rb` |
| Event model | `app/models/upcoming_change_event.rb` |
| Group model | `app/models/site_setting_group.rb` |
| Settings integration | `lib/site_setting_extension.rb` (search for `upcoming_change`) |
| CSS opt-in serializer | `app/serializers/site_serializer.rb` (`upcoming_changes_with_css`) |
| Defaults provider | `lib/site_settings/defaults_provider.rb` (default override activation/resolution) |
| Hidden provider | `lib/site_settings/hidden_provider.rb` (unions in `settings_hidden_while_enabled`) |
| Services | `app/services/upcoming_changes/*.rb` |
| Group upsert | `app/services/site_setting/upsert_groups.rb` |
| Controller | `admin/config/upcoming_changes_controller.rb` |
| Scheduled jobs | `app/jobs/scheduled/check_upcoming_changes.rb`, `app/jobs/scheduled/notify_admins_of_available_upcoming_changes.rb` |
| Problem check | `app/services/problem_check/upcoming_change_stable_opted_out.rb` |
| Initializer | `config/initializers/015-track-upcoming-change-toggle.rb` |
| Admin page | `admin/templates/admin-config/upcoming-changes.gjs` |
| Admin container | `admin/components/admin-config-areas/upcoming-changes.gjs` |
| Admin item | `admin/components/admin-config-areas/upcoming-change-item.gjs` |
| User view | `admin/components/admin-user-upcoming-changes.gjs` |
| Site settings svc | `frontend/discourse/app/services/site-settings.js` |
| App controller | `frontend/discourse/app/controllers/application.js` |
| Notifications | `frontend/discourse/app/lib/notification-types/upcoming-change-*.js` |
| Sidebar | `frontend/discourse/app/lib/sidebar/admin-sidebar.js` |
| Constants | `frontend/discourse/app/lib/constants.js` |
| Styles | `app/assets/stylesheets/admin/upcoming-changes.scss` |
| Core spec | `spec/lib/upcoming_changes_spec.rb` |
| Integrity spec | `spec/integrity/upcoming_change_metadata_spec.rb` (validates allowed metadata keys) |
| Serializer spec | `spec/serializers/site_serializer_spec.rb` (`#upcoming_changes_with_css`) |
| Hidden provider spec | `spec/lib/site_settings/hidden_provider_spec.rb` |
| Request spec | `spec/requests/admin/config/upcoming_changes_controller_spec.rb` |
| Admin system spec | `spec/system/admin_upcoming_changes_spec.rb` |
| Member system spec | `spec/system/member_upcoming_changes_spec.rb` |
| Job specs | `spec/jobs/scheduled/check_upcoming_changes_spec.rb`, `spec/jobs/scheduled/notify_admins_of_available_upcoming_changes_spec.rb` |
| Multisite spec | `spec/multisite/upcoming_changes_spec.rb` |
| Page objects | `spec/system/page_objects/pages/admin_upcoming_changes.rb`, `admin_upcoming_change_item.rb` |
| Test helpers | `spec/support/helpers.rb` (search for `mock_upcoming_change_metadata`) |
