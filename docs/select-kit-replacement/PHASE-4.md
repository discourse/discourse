# Phase 4 — Menus, generic selects and native selects (waves 3 and 4)

**Goal:** the menu-shaped controls land on the right primitive, and the high-volume generic and
native selects join the flag.

See [`ROLLOUT.md`](ROLLOUT.md), *DMenu or DSelect* and *Waves*. Re-sequenced 2026-10-14.

## Tasks

### Wave 3: menu-shaped value selects and action menus

- ☐ **DSelect:** the group dropdown, and value-type `DropdownSelectBox` uses (composer
  translation selector, sidebar edit filter). The notification-level family (group settings'
  `NotificationsButton` and its plugin and theme subclasses) waits on the route decision in
  `ROLLOUT.md`.
- ☐ **DMenu:** the 10 `DropdownSelectBox` subclasses, user deletion, reviewable bundled actions,
  category and tag admin dropdowns, bulk-select bookmarks. Callbacks registered on their
  `modifySelectKit` identifiers keep running. (composer-actions is excluded; it is replaced
  independently by `composer-actions-new`.)
- ☐ **Value pickers built on `DMenu`** (audited 2026-11-11, core and bundled plugins). Their
  trigger shows the current value and their rows choose among values, so the guideline points
  them at `DSelect`. Each one is decided on its own, and one we keep on `DMenu` is checked off
  with the reason. Already tracked elsewhere: the access control permission menu and the DSA
  rule field (PHASE-3), notification tracking (the open decision in `ROLLOUT.md`), and
  `DMultiSelect` (PHASE-1).
  - Core:
    - ☐ Revision visibility (`components/modal/history/visibility-menu.gjs`). Its rows leave
      out the current value, and it ends with "Delete revision" after a divider when the
      viewer can delete.
    - ☐ Pinned options (`components/pinned-options.gjs`).
    - ☐ Color mode (`components/interface-color-selector.gjs`). The trigger shows the mode as
      an icon.
    - ☐ Language switcher (`components/language-switcher.gjs`).
    - ☐ Nested replies sort (`components/nested/sort-selector.gjs`).
    - ☐ Emoji skin tone (`components/emoji-picker/diversity-menu.gjs`).
    - ☐ Design wizard body and heading fonts (`components/design-wizard/fonts-section.gjs`).
    - ☐ Messages inbox (`components/user-nav/messages-dropdown.gjs`). Its rows navigate.
    - ☐ Mobile navigation dropdown (`components/navigation-bar.gjs`). Its rows navigate, and
      the `extra-nav-item` outlet renders after them.
    - ☐ Filter controls sort (`ui-kit/d-filter-controls.gjs`).
    - ☐ Composer toolbar popup menus (`components/toolbar-popup-menu-options.gjs`): the post
      language selector (`instance-initializers/post-language-selector.js`, ending with a
      "None" value), and the heading and list menus (`lib/composer/toolbar.ts`), which mark the
      format at the cursor and apply it.
    - ☐ FormKit's `menu` control (`form-kit/components/fk/control/menu.gjs`). Only the
      styleguide uses it.
    - ☐ Admin dashboard date range (`admin/components/dashboard/date-range.gjs`). Its panel
      ends with Cancel and Apply buttons.
    - ☐ Grid pickers: `ui-kit/d-icon-grid-picker` and the emoji picker in value mode
      (`components/emoji-picker/index.gjs`). A grid is not a listbox, so these may stay.
  - Plugins:
    - ☐ chat: the channel list filter and sort submenus (`chat-channel-list-filter-menu.gjs`,
      `chat-channel-list-sort-choice.gjs`), a channel's notification level
      (`chat-channel-sidebar-context-notification-submenu.gjs`) and the search sort
      (`chat-search.gjs`).
    - ☐ discourse-ai: the gist toggle (`ai-gist-toggle.gjs`) and the agent list layout
      (`ai-agent-list-editor.gjs`).
    - ☐ discourse-events: the "Going" menu (`discourse-post-event/status.gjs`). It ends with
      "Leave event" after a divider while the user is going.
    - ☐ poll: a ranked-choice option's rank (`poll-option-ranked-choice-dropdown.gjs`).
    - ☐ live: the call submenus for devices, noise suppression, camera and layout
      (`live/call-submenu.gjs`).
    - ☐ discourse-workflows: the reference picker (`variable/reference-property-picker.gjs`), a
      hand-rolled filterable list with an "Edit as code" button above it; and the "Add
      attributes" menu (`configurators/fixed-collection.gjs`), a toggle set, so `@multiple`.
  - Mixed, to decide (value rows beside commands): the bookmark menu's reminder times, boards'
    add-from-topic column menu, the rich editor's table menu (an alignment group among
    commands), chat's channel list menu and live's audio and video menus (commands that open
    the value submenus above), the debug and admin dashboard checkbox panels, and the site
    traffic filter pills (they remove values but can't add any).
  - Trailing action options: three of these pickers end with a destructive action after a
    divider (the permission menu, revision visibility and "Going"). The action stays an option
    in the list, reached with the arrow keys and counted with the others, so a `:footer` button
    is ruled out. An option with `position: "end"` and `divider: "before"` sits there, so the
    other two can move the same way.
- ☐ `registerTopicFooterDropdown` gains an opt-in key.
- ☐ Customer ports for the live patches on direct `DropdownSelectBox` invocations (caret icons
  and hidden titles).

### Wave 4: generic value selects and native selects

- ☐ `ComboBox` and `MultiSelect` with static content, period chooser, notifications filter.
- ☐ **FormKit `select` and `DNativeSelect`:** decide between new control types and a switch inside
  the shared control; preserve value types, empty values, disabled state, labels and errors, form
  participation, and query parameters (`d-filter-controls`). Deprecate `DNativeSelect`.

## Exit criteria

- Every family above has joined, on the primitive the guideline picks.
- FormKit and native consumers pass in both modes, including mobile.
