# Patch replacement matrix

Each live `api.modifyClass` customization of select-kit, and the supported API it moves to when
its family joins `enable_new_select_controls`. The rows come from the verified audit summarized in
[`ROLLOUT.md`](ROLLOUT.md) (blast radius). That audit's per-repo list names customer repos, so it is
kept outside the repository.

A family joins only once the ports for its rows are done.

## Live customizations

| Kind | Sites | Targets today | Supported route | Status |
|---|---|---|---|---|
| Caret icons | 9 | `category-drop`, `tag-drop`, direct `DropdownSelectBox` uses | `select-options` transformer returning `caretIcon` | Planned (wave 0) |
| Hiding the title text | 2 | `category-drop`, direct `DropdownSelectBox` uses | `select-options` transformer returning `iconOnly` | Planned (wave 0) |
| None-row label | 1 | `category-drop` (one parent's subcategory drop) | `select-options` transformer returning `noneLabel` | Planned (wave 0) |
| Disabling a select from an outside flow | 1 | `form-template-chooser`, plus the composer's category and tag choosers through DOM queries | `select-options` transformer returning `disabled` | Planned (wave 0) |
| Row tooltips | 1 | every select-kit row | `select-content` sets `title` on items; DSelect renders it on the option | Planned (wave 0) |
| Filtering the category list | 2 | `category-chooser` | `select-content` (the current-category variant needs the call site's `@instanceContext`) | Available |
| Shortcut rows with their own change routing | 1 | `category-drop` | `select-content` for the rows, `select-on-change` (without calling `next()`) for the routing | Available |

`select-options` is a value transformer keyed on `identifiers`, like `select-content`. It receives
the select's presentation options and returns overrides, so an extension can change what only a
call site could set before. Its exact contract is settled when it is built.

## Other live patches

- **Changes only the patching plugin's own selects** (2 sites, `mini-tag-chooser` and `tag-chooser`
  `search`). Core migrating its call sites does not affect them, because third parties stay on
  legacy select-kit. Once those families join, the wave 0 `modifyClass` deprecation still reports
  these patches (it throws in development) although they keep working. Tell the owner before
  that wave.
- **Only does harm** (1 site, `group-member-dropdown`). The patch skips `super.didInsertElement`,
  so its intended icon and disabled state never apply and select-kit's listeners are never
  registered. Tell the owner; the component moves to `DMenu` in wave 3.

## Not ported

- **Dead today** (11 sites): they override members that no longer exist, live in files whose
  imports no longer resolve, or patch classes core no longer renders. Nothing to port.
- **Out of scope** (1 site): discourse-assign's patch on `topic-notifications-button`, a wrapper
  around the DMenu-based `NotificationsTracking`.
