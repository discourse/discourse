---
title: Upcoming change audiences
short_title: Upcoming change audiences
id: upcoming-change-audiences
---

Upcoming changes have two independent pieces of configuration: a boolean site setting enables the change, and an audience determines who receives it. By default, `SiteSettingGroup` optionally restricts the audience. Disabling a change preserves its audience for the next time it is enabled.

The admin interface uses a toggle to enable or disable a change, next to an always-visible group chooser. The chooser stays visible while the change is disabled so admins can see who it will apply to. The `allow_enabled_for` metadata controls whether the chooser is editable:

| Metadata                   | Group chooser                                                  |
| -------------------------- | -------------------------------------------------------------- |
| Omitted                    | Editable; defaults to the impact role's groups                 |
| `[everyone]`               | Locked to the impact role's groups; nothing is stored          |
| `[staff]`                  | Locked to staff                                                |
| `[specific_groups]`        | Editable; requires at least one selected group before enabling |
| `[staff, specific_groups]` | Editable; staff is locked and other groups can be added        |

`[everyone]` means the change only reads its boolean setting and cannot be scoped to groups. It does not mean the change affects every user: the locked chooser shows the groups from the `impact` role, so set the role to match who the change actually affects.

| Impact role   | Groups                                  |
| ------------- | --------------------------------------- |
| `all_members` | `logged_in_users` and `anonymous_users` |
| `staff`       | `staff`                                 |
| `admins`      | `admins`                                |
| `developers`  | `admins`                                |
| `moderators`  | `moderators`                            |

`everyone` must be the only entry when present. A staff-inclusive change always keeps staff in its audience, enforced by both the chooser and server validation. Resolve automatic groups by ID rather than assuming their names are English.

For editable changes without stored groups, the chooser displays the impact role's groups. These are not persisted until an admin saves. Adding and removing groups updates a local draft. The check button saves the selection; it is disabled until the draft changes. Failed saves retain the draft for retry. Saving exactly the role's groups, or both `logged_in_users` and `anonymous_users` (even with additional groups), removes the stored restriction. Existing saved restrictions take precedence over these defaults.

Saving an empty audience disables the change and clears its stored restriction. Editing the audience of a disabled change leaves it disabled, unless the admin just attempted to enable a change that requires a group; saving its first selected group completes that enablement.

The chooser uses `EmailGroupUserChooser` with `groupsOnly`, `useHeaderFilter`, and, when staff is required, `lockedValues`. Group-only search includes automatic groups and pseudogroups, excludes the legacy `everyone` group, and does not accept users, emails, or arbitrary pasted values. Locked selections cannot be removed by pointer or keyboard.

`PUT /admin/config/upcoming-changes/toggle` accepts `setting_name`, `enabled`, and optional `group_names`. Send JSON to preserve an explicit empty array. Omitting `group_names` preserves the stored audience; supplying it validates and persists the audience together with the enabled state. Backend eligibility recognizes `anonymous_users` for anonymous visitors and `logged_in_users` for authenticated users. An enabled change without a stored restriction applies to everyone.

Auto-promoted changes may already be enabled without stored groups despite restricted metadata. Rendering the controls does not write a scope; explicit admin edits apply the metadata restrictions.

The main toggle saves immediately and uses the last saved audience. Unsaved chooser edits are preserved locally and are only applied with the check button.

## Linked group settings

An upcoming change can declare `group_setting` to reuse an existing group-list site setting instead of maintaining a separate `SiteSettingGroup` restriction:

```yaml
new_feature_enabled:
  upcoming_change:
    status: experimental
    impact: feature,all_members
    group_setting: new_feature_allowed_groups
```

The referenced setting must have `type: group_list` and belong to core or the same plugin. `group_setting` cannot be combined with `allow_enabled_for`; mandatory and disallowed groups come from the linked setting instead.

In this mode the toggle only updates the boolean setting. The check button only updates the linked group setting through `SiteSetting::Update`, retaining its validation, confirmations, staff logs, and refresh behavior. The backend derives the target from trusted metadata, not the submitted group-setting name. The chooser displays the actual setting, including its default and mandatory groups, without synthetic prefills or writes.

The upcoming-change editor rejects an empty linked audience and directs the admin to use the toggle to disable the change. Empty group values saved elsewhere retain the group-list setting's meaning: nobody receives the change, while the master toggle remains unchanged. The check button also leaves the toggle unchanged when a nonempty audience is saved while the change is disabled.

Audience resolution reads the linked setting's effective `_map` value, including pseudogroup handling. Selecting both anonymous and logged-in groups stores both IDs in the linked setting; it does not clear the list. Linked restrictions continue to apply after the upcoming change becomes permanent. Any old `SiteSettingGroup` record for the flag is ignored and never copied over the linked setting.

`UpcomingChangeGroupControl` owns the local draft and check button. `UpcomingChangeItem` owns the toggle and chooses the audience save path. Related-setting links use their existing dependency behavior.
