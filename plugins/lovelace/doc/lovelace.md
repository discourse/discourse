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

## Editable checklist configuration

The page groups checklist items and the item bank in one column, with the member
preview alongside them. On narrow screens, the preview follows the checklist and
bank. All three areas use the same compact row style, with the title above the
description and controls alongside the text. Checklist rows have Edit, Remove,
and drag controls; preview rows have a checkbox and the item's action link; bank
rows have an Add button. New checklists start with three editable
suggestions:

| Item | Description | Button | Destination |
| --- | --- | --- | --- |
| Add a profile picture | Add a picture to make your profile stand out. | Add picture | The member's account settings |
| Complete your profile | Fill out your bio and other details so we can get to know you. | Complete profile | The member's profile settings |
| Read community guidelines | Learn about our community and how to participate here. | Read guidelines | The configured Guidelines topic, or `/guidelines` if no topic exists |

Existing saved configurations keep their items and order, including an
intentionally empty checklist. Unused suggestions are available in the item bank.

The bank initially offers **Set up your notifications**, with the description
“Turn on push notifications to keep up to speed with the community.” Its
**Set up notifications** button targets the member's notification settings.
Choose **Add** to append a suggestion and update the preview.
Suggestions use the same editing and reorder controls as custom items.

Removing an unchanged seeded item returns it to the bank immediately without a
confirmation prompt. Customized seeded items still require confirmation and keep
their edited title, description, destination, and button text in the bank.
Adding an item back restores those edits. Removing a custom item deletes it after
confirmation. The bank and
checklist save together, and refreshing preserves both. When all four suggestions
are selected, the bank indicates that all available items are in the checklist.

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
save immediately. Removing an item saves immediately; only customized suggestions
and custom items require confirmation.
Other list changes are disabled while an item form is open or a save is pending.

Opening a form without changing a field does not trigger a navigation warning.
Editing an unsaved field prompts before leaving the page or canceling the form.
Saving closes the form and clears the pending change. Checking preview items or
following preview links never creates an unsaved configuration change.

## Member preview

The preview shows the saved checklist in order, including titles, descriptions,
checkboxes, action links, and a completion count. Checkboxes update only this
page’s temporary progress. Links open in a new tab with the current
administrator’s permissions. Reloading or leaving the page resets preview
progress; it does not write member progress.

The editable checklist provides configuration and an administrator preview. It
is saved separately from the member suggestion checklist described below; its
items are not displayed on the member page. Neither interface stores member
completion progress or opens automatically after signup.

## Editable checklist authorization and persistence

Both reading and writing checklist configuration require a signed-in
administrator. Ordinary members and anonymous visitors cannot access the
configuration JSON API. Disabling Lovelace makes its endpoints unavailable.

`GET /lovelace/admin/checklist.json` returns items, the suggestion bank, and a
revision number. It also identifies selected items whose fields still match a
seeded suggestion, so the admin page can skip confirmation for safe returns to
the bank. This comparison is refreshed after saves and page loads.
`PUT` to the same endpoint accepts `items` and the revision last read. A revision
conflict returns HTTP 409 with a request to reload, preserving the other
administrator’s changes. Invalid item fields or unsafe URL schemes return HTTP
400 without changing the saved checklist. Writes retain Discourse’s CSRF
protection.

The starter `GET /lovelace/examples.json` endpoint remains available with its
original public/private-site behavior and returns `{"hello":"world"}`.

## Editable checklist architecture

The isolated Rails engine exposes the API under `/lovelace`. The checklist is
stored as one ordered configuration in Discourse’s PluginStore, with its bank,
a revision, and a distributed mutex to serialize writes. `ChecklistsController`
handles HTTP responses and delegates editable checklist updates to
`Lovelace::Checklist::Update`, a Discourse service. The service enforces the
enabled-plugin and administrator policies, validates and normalizes items through
`Checklist.normalize`, and saves the next revision together with the bank.
Reads continue to use `Checklist.read`. The server
validates fields, limits, link destination types, and URL schemes and supplies
fixed paths for settings links. No plugin tables, migrations, or background jobs
are needed.

Defaults are used only when no configuration has been saved. Stable suggestion
IDs let the server return removed suggestions to the bank while retaining edits.
Old configurations without a bank receive any unused suggestions without changing
their selected items.
The server derives bank changes from the previous saved configuration and the
submitted item list; bank additions use the same validated, revision-checked save
as other edits.

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

## Member suggestion checklist

Open **Admin → Plugins → Lovelace → Onboarding checklist** at
`/admin/plugins/lovelace/checklist`. The initial checklist contains:

| Item | Description | Button | Destination |
| --- | --- | --- | --- |
| Add a profile picture | Add a picture to make your profile stand out. | Add picture | The current member's account preferences |
| Complete your profile | Fill out your bio and other details so we can get to know you. | Complete profile | The current member's profile preferences |
| Read community guidelines | Learn about our community and how to participate here. | Read guidelines | The configured Guidelines topic, or `/guidelines` if no topic exists |

The item bank initially contains **Set up your notifications**, with the description
“Turn on push notifications to keep up to speed with the community.” Its button,
**Set up notifications**, links to the current member's notification preferences.

Choose **Add** to append a bank item to the checklist. Choose
**Return to bank** to remove a checklist item and make it available for reuse.
Changes save immediately and apply to all members. Refreshing the page keeps the
selection, including an empty checklist. These four suggestions are the available
catalogue; item text and destinations cannot be edited in this interface.

Signed-in members can open `/lovelace/checklist` to see the selected items and
follow their buttons. Preference links always belong to the member viewing the
page. The checklist provides suggested actions; it does not track completion or
automatically open after signup.

## Member checklist authorization

Only administrators can configure the checklist or see the item bank. Regular
members and moderators can read the selected checklist but cannot change it.
Anonymous JSON requests receive HTTP 403. Disabling Lovelace makes its endpoints
unavailable with HTTP 404 for signed-in users. Changes use authenticated PUT
requests with Discourse's normal CSRF protection.

The original `GET /lovelace/examples.json` endpoint remains available and returns
`{"hello":"world"}`. It allows anonymous access on public sites; sites requiring
login reject anonymous JSON requests with HTTP 403.

## Member checklist architecture

`plugin.rb` registers the enable setting, stylesheet, and admin plugin entry, and
loads the isolated `Lovelace::Engine` mounted at `/lovelace`.
The shared `ChecklistsController` serves the member page and JSON representation
and enforces administrator access for updates. The shared `Checklist` class in
`lib/lovelace/checklist.rb` also defines stable suggestion IDs, translates their
content, and resolves destinations for the current member. A single admin
navigation initializer registers both configuration tabs.

Selections are stored as an ordered list of IDs under the `checklist_items` key
in Discourse's PluginStore, separately from the editable preview's `checklist`
key. An absent selection uses the three defaults; an explicitly saved empty list stays
empty. The bank is the catalogue minus the selected IDs, so removing an item
never destroys it. Updates validate that every ID is known and appears once.
No plugin database tables or background jobs are needed.

The member and admin pages share a checklist component. The admin page uses
Discourse's plugin configuration navigation. Each change waits for the server's
response before displaying the new selection, disables further changes while
saving, and displays Discourse's error dialog if saving fails.

## Tests

Run from the Discourse repository root:

```sh
LOAD_PLUGINS=1 RAILS_ENV=test bin/rspec plugins/lovelace/spec/requests
LOAD_PLUGINS=1 RAILS_ENV=test bin/rspec plugins/lovelace/spec/services
pnpm --dir frontend/discourse build
LOAD_PLUGINS=1 bin/rake assets:precompile:build_plugins
LOAD_PLUGINS=1 RAILS_ENV=test bin/rspec plugins/lovelace/spec/system/configure_member_onboarding_spec.rb
LOAD_PLUGINS=1 RAILS_ENV=test bin/rspec plugins/lovelace/spec/system/checklist_spec.rb
```

Request specs cover authorization, disabled-plugin behavior, persistence,
reordering, removal, supported destinations, invalid payloads, and stale writes.
Service specs cover direct-call authorization, checklist normalization, invalid
input, revision conflicts, saving or clearing the configuration, and preserving
edited suggestions in the bank when removing and restoring them.
The onboarding system spec covers adding and editing items, compact saved rows,
temporary toasts, preview progress, navigation warnings, reordering, removal, and
persistence after refresh. It also checks the seeded defaults, returning an edited
suggestion to the bank, restoring it, adding notifications, preview links, and
retaining the checklist and bank after refresh. Layout checks cover the controls
in all three areas, checking and unchecking preview items, and keeping the bank
next to the checklist on wide and narrow screens. Removal checks verify that
unchanged suggestions return immediately, while customized suggestions still
allow cancellation or confirmation after a reload. The existing core-features
system spec checks normal forum interactions with the plugin enabled.

Request specs also cover editable suggestion defaults, destinations, returning
edited defaults to the bank, restoring edits, existing and empty configurations,
and conflicts during bank additions. Member checklist specs cover suggestion
defaults, member destinations, the bank, empty selections, invalid IDs, and
isolation between the two saved configurations. The
checklist system spec covers both admin tabs, adding and returning suggestions,
refreshing, and member preference links.
