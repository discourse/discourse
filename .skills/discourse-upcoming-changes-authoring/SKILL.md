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

- `resolved_value(setting_name)` — Determines the *effective* value of a setting. This is where auto-promotion logic lives: if a setting's status meets/exceeds `promote_upcoming_changes_on_status`, the resolved value is `true` even if the DB default is `false`. Permanent settings always resolve to `true` (admins can't disable them).
- `enabled_for_user?(setting_name, user)` — The primary access check. Considers: resolved value, group restrictions, anonymous users (only get access if no group restrictions).
- `stats_for_user(user:, acting_guardian:)` — Returns per-change status for a user including *why* they have/don't have access (the `user_enabled_reasons` enum).
- `current_statuses` / `permanent_upcoming_changes` — Cached lookups keyed by git version (one-time cost per deploy). Cleared by `clear_caches!` and automatically when `TrackNotifyStatusChanges` detects changes.

**`app/models/upcoming_change_event.rb`** — Audit trail. Every lifecycle event (added, removed, status change, manual toggle, admin notification) is recorded here. Has unique indexes to prevent duplicate events of specific types per change.

**`lib/site_setting_extension.rb`** — Where `upcoming_change:` metadata in `site_settings.yml` gets parsed. When a setting is registered with this metadata, it stores the parsed result in `@upcoming_change_metadata` and defines a `{name}_groups_map` method. The `impact` string is split into `impact_type` and `impact_role`.

**`app/models/site_setting_group.rb`** — Stores group restrictions for settings. Group IDs are pipe-separated strings (`"1|2|3"`). The `setting_group_ids` class method returns a hash used for in-memory caching.

### Services Layer

All services use `Service::Base`. They're organized under `app/services/upcoming_changes/`:

| Service | Purpose |
|---------|---------|
| `List` | Admin-only, fetches all changes with metadata, group data, and images |
| `Toggle` | Admin enable/disable — updates SiteSetting, clears groups if `disallow_enabled_for_groups`, logs staff action, fires DiscourseEvent |
| `Track` | Orchestrator called by the scheduled job — delegates to three action sub-services |
| `TrackNotifyAddedChanges` | Compares current settings against event history, creates `added` events |
| `TrackRemovedChanges` | Creates `removed` events for settings no longer present |
| `TrackNotifyStatusChanges` | Detects status changes in metadata, creates events, clears caches |
| `NotifyPromotions` | Iterates all changes and calls `NotifyPromotion` for each |
| `NotifyPromotion` | Handles one promotion — checks policies, merges notifications, fires events |
| `NotifyAdminsOfAvailableChange` | Notifies admins when a change reaches one status below promotion threshold |
| `NotificationDataMerger` | Consolidates multiple change notifications into one to avoid spam |

**`SiteSetting::UpsertGroups`** — Manages group assignments for settings (upserts `SiteSettingGroup`, refreshes caches, notifies clients).

### Scheduled Job

**`app/jobs/scheduled/check_upcoming_changes.rb`** — Runs every 20 minutes inside a `DistributedMutex`. Calls `Track` then `NotifyPromotions`. Supports verbose logging via the `upcoming_change_verbose_logging` setting.

### Frontend

**Admin page** — `admin/templates/admin-config/upcoming-changes.gjs` renders the page header, `admin/components/admin-config-areas/upcoming-changes.gjs` is the container with filtering, and `admin/components/admin-config-areas/upcoming-change-item.gjs` renders each row.

**Key frontend patterns:**
- Filtering by status, impact type, impact role, and enabled/disabled state via `AdminFilterControls`
- Group selection uses a multi-select dropdown with debounced API saves
- Toast notifications for all toggle/group changes
- Lightbox integration for preview images

**Site settings service** (`app/services/site-settings.js`) — Loads upcoming changes from `PreloadStore`, applies them as overrides to site settings, and stores them in `settings.currentUserUpcomingChanges`.

**Body CSS classes** — `app/controllers/application.js` generates `uc-{dasherized-key}` classes on `<body>` for each enabled upcoming change, allowing CSS-based feature gating.

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

## Key Design Decisions

### Caching Strategy

The `current_statuses` and `permanent_upcoming_changes` caches are keyed by git version (`Discourse.git_version`). This means they're naturally invalidated on every deploy — no TTL needed. Within a deploy, `TrackNotifyStatusChanges` calls `clear_caches!` when it detects metadata changes. Always call `clear_caches!` in tests after modifying metadata.

### Auto-Promotion

The `resolved_value` method is the single source of truth for whether a setting is "on." Auto-promotion happens implicitly: when a setting's status meets the threshold, `resolved_value` returns `true` regardless of the DB value. The DB value only changes when an admin explicitly toggles. This separation means promotion is reversible by the admin without losing the original opt-in/opt-out state.

### Notification Merging

When multiple changes need notifications, `NotificationDataMerger` consolidates them into a single notification per admin. It finds existing unread notifications and merges the change names array. The frontend notification types handle singular ("Feature X"), dual ("Feature X and Feature Y"), and many ("Feature X and 2 others") display.

### New Site Notification Suppression

Notifications for `added` and `promoted` changes are skipped on new sites (determined by `Migration::Helpers.new_site?` in `lib/migration/helpers.rb` — a site is "new" if its first schema migration was less than 1 hour ago). This prevents freshly provisioned sites from being flooded with notifications for every existing upcoming change on their first run. The tracking/detection steps still execute — only the notification delivery is suppressed.

### Group-Based Access

Group restrictions use a separate `SiteSettingGroup` model rather than storing groups on the setting itself. This allows the caching layer (`site_setting_group_ids`) to work independently. When `disallow_enabled_for_groups` is set in metadata, the UI only shows Everyone/No One options. Group IDs are pipe-separated in the DB for efficient single-row storage.

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
    },
  },
)
```

Always clean up with `clear_mocked_upcoming_change_metadata` in an `after` block (or the helper handles it automatically depending on context). The helper is defined in `spec/support/helpers.rb`.

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
| Services | `app/services/upcoming_changes/*.rb` |
| Group upsert | `app/services/site_setting/upsert_groups.rb` |
| Controller | `admin/config/upcoming_changes_controller.rb` |
| Scheduled job | `app/jobs/scheduled/check_upcoming_changes.rb` |
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
| Request spec | `spec/requests/admin/config/upcoming_changes_controller_spec.rb` |
| Admin system spec | `spec/system/admin_upcoming_changes_spec.rb` |
| Member system spec | `spec/system/member_upcoming_changes_spec.rb` |
| Job spec | `spec/jobs/scheduled/check_upcoming_changes_spec.rb` |
| Multisite spec | `spec/multisite/upcoming_changes_spec.rb` |
| Page objects | `spec/system/page_objects/pages/admin_upcoming_changes.rb`, `admin_upcoming_change_item.rb` |
| Test helpers | `spec/support/helpers.rb` (search for `mock_upcoming_change_metadata`) |
