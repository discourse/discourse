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
