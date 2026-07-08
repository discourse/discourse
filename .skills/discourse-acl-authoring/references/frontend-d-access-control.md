# DAccessControl Frontend Usage

Use this reference when adding or reviewing UI that lets users edit ACLs.

## Component Contract

Import:

```gjs
import DAccessControl from "discourse/ui-kit/d-access-control";
```

Basic usage:

```gjs
<DAccessControl
  @groups={{this.site.groups}}
  @acl={{field.value}}
  @aclTarget="DiscourseKanban::Board"
  @onChange={{this.aclChanged}}
  @transformPermissionOptions={{this.transformPermissionOptions}}
/>
```

Arguments:

- `@groups`: group records available for selection. Each group should have `id`, `name`, `full_name`, and `automatic`.
- `@acl`: flattened ACL entries from the backend or form state. The backend can emit group and user entries, and this component can add groups from the preloaded `@groups` list plus user/group search results from the ACL grantee search endpoint.
- `@onChange`: called with the next flattened ACL array when the user adds/removes/changes a row.
- `@aclTarget`: optional key used to load mandatory ACL entries from `site.access_control.mandatory_acl` and banned entries from `site.access_control.banned_acl`.
- `@transformPermissionOptions`: optional callback to customize default permission labels/descriptions or add target-specific permissions.

`@aclTarget` must match `target_class.acl_target_key`; by default this is the Ruby class name such as `"DiscourseKanban::Board"`.

## Controlled Component Behavior

`DAccessControl` is controlled by its parent. It calls `@onChange(nextAcl)` on user actions, and the parent must write the returned array back into form state.

Example:

```js
@action
aclChanged(acl) {
  this.formApi.set("acl", acl);
}
```

Mandatory ACL rows are injected for display from `this.site.access_control`. The component does not call `@onChange` during render when it injects mandatory rows. Backend saves must still call `AccessControlListManager` with the submitted ACL array so mandatory entries are injected server-side too.

Banned ACL rows are also read from `this.site.access_control`. The component filters matching permission options for the row's grantee by comparing `permission`, `type`, and `id`. This is only a UX guard; backend saves must still go through `AccessControlListManager`, which rejects banned entries.

## Permission Options

Default permissions:

- `view`, level 1
- `edit`, level 2
- `remove`, appended as a destructive option

Use `@transformPermissionOptions` for domain-specific copy or added permissions:

```js
@action
transformPermissionOptions(options) {
  const viewOption = options.find((option) => option.id === "view");
  viewOption.description = i18n("plugin.target.permission_view_description");

  options.push({
    id: "manage",
    level: 3,
    name: i18n("plugin.target.permission_manager"),
    description: i18n("plugin.target.permission_manager_description"),
  });

  return options;
}
```

Keep permission copy aligned with backend semantics. If a displayed `manage` role also requires a global site setting or staff gate, make that clear in the surrounding UI or choose a different label.

Target-specific options added via `@transformPermissionOptions` can still be banned for individual grantees. For example, a target may add `manage` and then define `banned_acl` entries that remove `edit` and `manage` from the `anonymous_users` auto group.

## Row Behavior

- Rows are sorted with mandatory rows first, then by group name.
- Mandatory rows show a lock icon, are styled with `--mandatory`, and have their permission select disabled.
- A mandatory ACL replaces an existing row for the same type/id in the component's display list.
- Banned permissions are filtered per row only when the banned entry's `type`, `id`, and `permission` match the row.
- The remove action remains available unless the row is mandatory.
- Newly added regular groups default to `edit`.
- Read-only default auto groups (`anonymous_users`, `everyone`, `trust_level_0`) default to `view`.
- Already selected grantees are removed from the add-group chooser's preloaded and remote results.
- The add control uses `EmailGroupUserChooser` through a DAccessControl-specific wrapper. Preloaded group results preserve numeric group IDs in the ACL payload while displaying group names.
- Typed add-control searches call `/access-control/grantees/search`, which returns `{ users: [...], groups: [...] }` scoped to the current user's visible users/groups.
- User rows added from search keep `username`, `name`, and `avatar_template` on the ACL entry so the rendered row can pass them through `rowAsUser` to `dAvatar`.
- Group rows added from preloaded or remote results keep `name`, `flair_url`, `flair_bg_color`, and `flair_color` on the ACL entry so the rendered row can pass them to `DAvatarFlair`; groups without `flair_url` render the generic `user-group` icon.
- Row DOM metadata uses `data-row-type` and `data-row-id`; tests should not rely on the old `data-group-id` attribute.

The component is still group-first for preloaded data and mandatory ACL injection. Backend ACL rows can include `type: :user` entries and lookup helpers understand them, but mandatory user ACL display still needs explicit UI support if a target defines user mandatory entries.

## FormKit Integration

When used inside a FormKit custom field:

```gjs
<form.Field
  @name="acl"
  @title={{i18n "plugin.target.access"}}
  @description={{i18n "plugin.target.access_description"}}
  @format="max"
  @type="custom"
  @validate={{this.validateAccess}}
  as |field|
>
  <field.Control>
    <DAccessControl
      @groups={{this.site.groups}}
      @acl={{field.value}}
      @aclTarget="Plugin::Target"
      @onChange={{this.aclChanged}}
      @transformPermissionOptions={{this.transformPermissionOptions}}
    />
  </field.Control>
</form.Field>
```

Validate the form state client-side for user experience, but rely on server-side validation and `AccessControlListManager` for actual enforcement.

## Testing

Core component tests live in `frontend/discourse/tests/integration/components/d-access-control-test.gjs`.

Consumer tests should cover:

- target-specific permission options are present
- `@aclTarget` renders mandatory rows from `site.access_control`
- `@aclTarget` filters banned permissions from `site.access_control` for the matching grantee only
- mandatory rows are locked and not duplicated
- `@onChange` updates parent/form state when the user changes a row
- default ACL construction for new records includes expected groups, if the consumer builds defaults
- selectors use `.d-access-control__row[data-row-type="group"][data-row-id="..."]` for row assertions
