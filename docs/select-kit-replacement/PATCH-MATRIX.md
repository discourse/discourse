# Patch replacement matrix

Each live `api.modifyClass` customization of select-kit, and the supported API it moves to when
its family joins `enable_new_select_controls`. The rows come from the verified audit summarized in
[`ROLLOUT.md`](ROLLOUT.md) (blast radius). That audit's per-repo list names customer repos, so it is
kept outside the repository.

A family joins only once the ports for its rows are done.

## Live customizations

| Kind | Sites | Targets today | Supported route | Status |
|---|---|---|---|---|
| Caret icons | 10 | `category-drop`, `tag-drop`, direct `DropdownSelectBox` uses (one site applies `selectKitOptions` to the classes directly instead of `modifyClass`) | `spec.options` through `forKind`: `caretIcon` for the category drop (kind `select-category-filter`), the tag drop (kind `select-tag-filter`) and the dropdowns | Available |
| Hiding the title text | 2 | `category-drop`, direct `DropdownSelectBox` uses | `spec.options` returning `iconOnly`; the recipe or call site passes `@ariaLabel`. The category drop (kind `select-category-filter`) draws the core caret, so `iconOnly` needs no other option there | Available |
| Empty-selection trigger text | 1 | `category-drop` (one parent's subcategory drop; the drop has no none row, the patch changes the trigger's no-selection text and title) | `spec.options` returning `placeholder`, through `forIdentifier("breadcrumb-category")` (or `forKind("select-category-filter")`), narrowed to the parent with `kindContext.parentCategory`. An empty level holds nothing, so the placeholder is what it shows. The title change is dropped on purpose: DSelect draws no title, and the visible text already says it | Available |
| Disabling a select from an outside flow | 1 | `form-template-chooser`, plus the composer's category and tag choosers through DOM queries | `spec.options` returning `disabled`, through `forIdentifier` | Available |
| Row tooltips | 1 | every select-kit row | `spec.row` setting `title` | Available |
| Filtering the category list | 2 | `category-chooser` | `spec.content` through `forKind("select-category")`, or `forIdentifier("composer-category")` and `forIdentifier("topic-edit-category")` for those two choosers, whose `instanceContext` carries the composer model or the topic (the current-category variant reads it) | Available |
| Shortcut rows with their own change routing | 1 | `category-drop` | `spec.content` for the rows and `spec.change` (without calling `next()`) for the routing, through `forKind("select-category-filter")`; the recipe has no shortcut or URL options, since the call site owns routing | Available |
| Reordering notification levels | 1 | `notifications-button` (group settings); the same patch also overrides opening the menu | Depends on the notification-level route (open decision, `ROLLOUT.md`) | Open |

Every route is a setup on the `select-customizations` value transformer, registered with
`forKind` (what the select is) or `forIdentifier` (one call site). `spec.options` overrides
presentation that only a call site could set before. The contract is in the DSelect README
(`frontend/discourse/app/ui-kit/select/README.md`, Extension points).

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

- **Dead today** (10 sites): they override members that no longer exist, live in files whose
  imports no longer resolve, or patch classes core no longer renders. Nothing to port.
- **Out of scope** (1 site): discourse-assign's patch on `topic-notifications-button`, a wrapper
  around the DMenu-based `NotificationsTracking`.
