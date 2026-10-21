# Lovelace product guide

## Installation and configuration

Lovelace loads from `plugins/lovelace/` with the containing Discourse installation.
It uses Discourse’s Ruby and JavaScript dependencies and needs no separate
installation or database migration. Enable the `lovelace_enabled` site setting
(default: enabled).

Open **Admin → Plugins → Lovelace → Member onboarding**, or visit
`/admin/plugins/lovelace/member-onboarding` directly. The standard Settings tab
contains the plugin enable setting. All administrators can configure the
checklist; there is no subscription plan restriction or upgrade requirement.

## Checklist configuration

The page presents checklist items and a member preview side by side, stacking
these sections on narrow screens. The checklist starts empty.

Choose **Add checklist item** to open a form. Each item has a title, description,
link destination, and button text. Title and button text are required. Limits are
120 characters for titles, 1,000 for descriptions, 80 for button text, 2,048 for
links, and 50 items per checklist.

Link destinations include:

- Category: enter a community path such as `/c/general/1`.
- Topic: enter a community path such as `/t/welcome/123`.
- Chat channel: enter a community path such as `/chat/c/general/1`.
- Profile, notification, or account settings: the link automatically targets the
  corresponding `/my/preferences/…` page for the signed-in member.
- Custom URL: enter a community path beginning with a single `/`, or a full
  HTTP or HTTPS URL.

Links do not grant access to their destination. Choose destinations that intended
members can access; chat links require an available chat channel. Category,
topic, and chat fields accept paths rather than providing a resource search.

Choose **Save item** to persist an addition or edit. A successful save closes the
form and leaves a compact row with its title, description, Edit button, drag
handle, and removal control. The “Checklist saved.” toast disappears on its own.
Failed saves keep the form open for correction.

Drag a handle to reorder items. Clicking a handle also offers move options, and
keyboard users can focus a handle and use Alt+Arrow keys to move an item. Reorders
save immediately. Removing an item requires confirmation and saves immediately.
Other list changes are disabled while an item form is open or a save is pending.

Opening a form without changing a field does not trigger a navigation warning.
Editing an unsaved field prompts before leaving the page or canceling the form.
Saving closes the form and clears the pending change. Checking preview items or
following preview links never creates an unsaved configuration change.

## Member preview

The preview shows the saved checklist in order, including descriptions,
checkboxes, button text, and a completion count. Checkboxes update only this
page’s temporary progress. Links open in a new tab with the current
administrator’s permissions. Reloading or leaving the page resets preview
progress; it does not write member progress.

This implementation provides configuration and an administrator preview. It does
not yet display a checklist to newly registered members or store their progress.

## Authorization and persistence

Both reading and writing checklist configuration require a signed-in
administrator. Ordinary members and anonymous visitors cannot access the
configuration JSON API. Disabling Lovelace makes its endpoints unavailable.

`GET /lovelace/admin/checklist.json` returns items and a revision number.
`PUT` to the same endpoint accepts `items` and the revision last read. A revision
conflict returns HTTP 409 with a request to reload, preserving the other
administrator’s changes. Invalid item fields or unsafe URL schemes return HTTP
400 without changing the saved checklist. Writes retain Discourse’s CSRF
protection.

The starter `GET /lovelace/examples.json` endpoint remains available with its
original public/private-site behavior and returns `{"hello":"world"}`.

## Architecture

The isolated Rails engine exposes the API under `/lovelace`. The checklist is
stored as one ordered configuration in Discourse’s PluginStore, with a revision
and a distributed mutex to serialize writes. `ChecklistsController` handles HTTP
responses and delegates updates to `Lovelace::Checklist::Update`, a Discourse
service. The service enforces the enabled-plugin and administrator policies,
validates and normalizes items through `Checklist.normalize`, and saves the next
revision. Reads continue to use `Checklist.read`. The server validates fields,
limits, link destination types, and URL schemes and supplies fixed paths for
settings links. No plugin tables, migrations, or background jobs are needed.

The revision check alone cannot prevent simultaneous overwrites: two requests
could both read revision 3, both pass the check, and both save revision 4. The
service’s `lock` step uses Discourse’s Redis-backed `DistributedMutex` to keep
reading the current checklist, checking its revision, and saving the replacement
inside one critical section. The second request reads the newly saved revision
and fails with HTTP 409 rather than overwriting it. The lock covers all checklist
updates across Discourse processes; a Ruby mutex would protect only one process.
Validation happens before acquiring the lock, and rendering happens after it is
released, keeping the critical section small. A database transaction alone would
not serialize this read/check/write sequence in PluginStore.

The plugin registers a standard admin plugin tab and page subheader. FormKit
owns validation and unsaved draft checks, and is mounted only while adding or
editing an item. The preview’s checkbox state is separate from the form and from
persisted configuration. The shared reorderable list supplies drag, menu, and
keyboard interactions; the standard toast service supplies temporary save
feedback. All interface strings are translatable, and item text is escaped.

## Tests

Run from the Discourse repository root:

```sh
LOAD_PLUGINS=1 RAILS_ENV=test bin/rspec plugins/lovelace/spec/requests
LOAD_PLUGINS=1 RAILS_ENV=test bin/rspec plugins/lovelace/spec/services
pnpm --dir frontend/discourse build
LOAD_PLUGINS=1 bin/rake assets:precompile:build_plugins
LOAD_PLUGINS=1 RAILS_ENV=test bin/rspec plugins/lovelace/spec/system/configure_member_onboarding_spec.rb
```

Request specs cover authorization, disabled-plugin behavior, persistence,
reordering, removal, supported destinations, invalid payloads, and stale writes.
Service specs cover direct-call authorization, checklist normalization, invalid
input, revision conflicts, and saving or clearing the configuration.
The onboarding system spec covers adding and editing items, compact saved rows,
temporary toasts, preview progress, navigation warnings, reordering, removal, and
persistence after refresh. The existing core-features system spec checks normal
forum interactions with the plugin enabled.
