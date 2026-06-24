# Backend Model and Permission Lookups

Use this reference when working with `AccessControlList`, `AclTarget`, `Acl::Target`, `Acl::User`, `Guardian`, or target visibility queries.

## Data Shape

`AccessControlList` stores one row per `(target_type, target_id, permission)`.

Important columns:

- `target_type`, `target_id`: polymorphic target.
- `permission`: freeform string such as `view`, `edit`, `manage`, or target-specific permissions.
- `allowed_group_ids`: bigint array of groups that hold the permission.
- `allowed_user_ids`: bigint array exists, but current authoring/UI support is incomplete.
- `owner`: string identifying the owning subsystem, usually `"core"` or a plugin name.

The model has a uniqueness validation and DB index for target + permission. Multiple groups for the same permission collapse into one row.

## Flattened vs Expanded ACLs

The frontend and service params use flattened entries:

```ruby
[
  { type: "group", id: group.id, permission: "view" },
  { type: "group", id: other_group.id, permission: "edit" },
]
```

`AccessControlList.expand_list(list, target, owner)` groups those entries by permission and returns rows suitable for `insert_all!`.

`AccessControlList.where(target: target).flattened_list` returns one entry per group per permission, including group metadata:

```ruby
{
  type: :group,
  id: group.id,
  permission: "view",
  mandatory: false,
  name: group.name,
  full_name: group.full_name,
  metadata: { auto_group: group.automatic? },
  target_id: target.id,
  target_type: target.class.polymorphic_name,
}
```

Pass `for_target:` only when every row is for the same target; mixed targets raise `Acl::MixedTargetError`.

## Matching Users and Groups

`AccessControlList.matching_user(user)` returns ACL rows applying to a user:

- Anonymous users match `Group::AUTO_GROUPS[:anonymous_users]`.
- Logged-in users match direct user rows, `user.belonging_to_group_ids`, and `logged_in_users`.
- Logged-in users match `everyone` only while `SiteSetting.granular_anonymous_and_logged_in_groups_permissions` is disabled.

`AccessControlList.matching_group(group)` returns ACL rows granted directly to the group or directly to users in that group.

## Lookup Objects

`AccessControlList#target_acl(target)` builds `Acl::Target` for a single target:

```ruby
target.permission_acl.group_has_permission?(group, "view")
target.permission_acl.group_has_any_permission?(group.id, %w[edit manage])
target.permission_acl.permission_group_ids("view")
target.permission_acl.multi_permission_group_ids(%w[view edit manage])
```

`AccessControlList#user_acl` builds `Acl::User` for a user:

```ruby
user.permission_acl.has_target_permission?(target, "view")
user.permission_acl.has_any_target_permission?(target, %w[edit manage])
user.permission_acl.target_ids_with_permission(TargetClass, "view")
user.permission_acl.target_ids_with_any_permissions(TargetClass, %w[view edit])
```

`User#permission_acl` and `Guardian::AnonymousUser#permission_acl` cache these lookups. Reload target records before reusing `target.permission_acl` after ACL writes.

## Guardian Helpers

Use the helper methods on `Guardian` instead of reaching into `user.permission_acl` from controllers:

```ruby
guardian.has_acl_permission?(target, "view")
guardian.has_any_acl_permission?(target, %w[edit manage])
guardian.target_ids_with_acl_permission(TargetClass, "view")
guardian.target_ids_with_any_acl_permissions(TargetClass, %w[view edit manage])
```

Build domain-specific Guardian methods around those helpers:

```ruby
def can_read_board?(board)
  return true if board.anonymous_can_read?
  return true if can_write_board?(board)

  has_acl_permission?(board, "view")
end

def can_write_board?(board)
  has_any_acl_permission?(board, %w[edit manage])
end
```

If a permission also requires a global gate, make that explicit in the domain method name/copy. For example, a site setting gate plus ACL `manage` is not the same as ACL `manage` alone.

## AclTarget

Include `AclTarget` in any model that owns ACL rows:

```ruby
class Board < ActiveRecord::Base
  include AclTarget
end
```

The concern provides:

- `has_many :access_control_lists, as: :target, dependent: :destroy`
- `permission_acl`, backed by `AccessControlList.where(target: self).target_acl(self)`
- reload cache clearing for `@permission_acl`
- `.acl_target_key`, defaulting to `name`
- `.has_mandatory_acl?`
- `.acl_is_mandatory?(acl)`
- `mandatory_acl_as_expanded_list(owner)`

## Mandatory ACLs

Define `self.mandatory_acl` on the target class when some grants must always exist:

```ruby
def self.mandatory_acl
  [{ type: :group, id: Group::AUTO_GROUPS[:admins], permission: "manage" }]
end
```

Mandatory entries are consumed by both backend writes and frontend rendering:

- `AccessControlList.inject_mandatory_acl(flattened_acl, target)` appends missing mandatory entries.
- `AccessControlListManager` calls that method before inserting rows.
- `flattened_list` marks matching entries with `mandatory: true`.
- `Site#access_control` exposes mandatory ACL metadata for registered targets.

Keep mandatory ACLs group-based unless user ACL support has been completed end-to-end.
