# Backend Model and Permission Lookups

Use this reference when working with `AccessControlList`, `AclTarget`, `Acl::Target`, `Acl::User`, `Guardian`, or target visibility queries.

## Data Shape

`AccessControlList` stores one row per `(target_type, target_id, permission)`.

Important columns:

- `target_type`, `target_id`: polymorphic target.
- `permission`: freeform string such as `view`, `edit`, `manage`, or target-specific permissions.
- `allowed_group_ids`: bigint array of groups that hold the permission.
- `allowed_user_ids`: bigint array of users that hold the permission. Backend lookup and persistence support is partial; the main remaining gap is complete `DAccessControl` user editing.
- `owner`: string identifying the owning subsystem, usually `"core"` or a plugin name.

The model has a uniqueness validation and DB index for target + permission. Multiple groups for the same permission collapse into one row.

## Flattened vs Expanded ACLs

The frontend and service params use flattened entries:

```ruby
[
  { type: "group", id: group.id, permission: "view" },
  { type: "user", id: user.id, permission: "edit" },
]
```

`AccessControlList.expand_list_for_bulk_insert(list, target, owner)` groups those entries by permission and returns rows suitable for `insert_all!`. It fills both `allowed_group_ids` and `allowed_user_ids`.

`AccessControlList.where(target: target).flattened_list` returns one entry per group or user per permission. Group entries include group metadata:

```ruby
{
  type: :group,
  id: group.id,
  permission: "view",
  mandatory: false,
  display_name: group.full_name.presence || group.name,
  metadata: { auto_group: group.automatic? },
  target_id: target.id,
  target_type: target.class.polymorphic_name,
}
```

User entries use `type: :user`, `display_name: user.display_name`, and do not include group metadata.

Pass `for_target:` only when every row is for the same target; mixed targets raise `Acl::MixedTargetError`.

## Matching Users and Groups

`AccessControlList.matching_user(user)` returns ACL rows applying to a user:

- Anonymous users match `Group::AUTO_GROUPS[:anonymous_users]`.
- Anonymous users also match `everyone` while `SiteSetting.granular_anonymous_and_logged_in_groups_permissions` is disabled.
- Logged-in users match direct user rows, `user.belonging_to_group_ids`, and `logged_in_users`.
- Logged-in users match `everyone` only while `SiteSetting.granular_anonymous_and_logged_in_groups_permissions` is disabled.

`AccessControlList.matching_group(group)` returns ACL rows granted directly to the group or directly to users in that group.

Use `AccessControlList.preload_allowed` before flattening relations that may include many rows. It batches group and user lookups, then memoizes `allowed_groups_preloaded` and `allowed_users_preloaded`.

## Lookup Objects

`AccessControlList#target_acl(target)` builds `Acl::Target` for a single target:

```ruby
target.permission_acl.group_has_permission?(group, "view")
target.permission_acl.group_has_any_permission?(group.id, %w[edit manage])
target.permission_acl.permission_group_ids("view")
target.permission_acl.group_ids_with_any_permission(%w[view edit manage])
target.permission_acl.user_has_permission?(user, "view")
target.permission_acl.user_has_any_permission?(user.id, %w[edit manage])
target.permission_acl.permission_user_ids("view")
target.permission_acl.user_ids_with_any_permission(%w[view edit manage])
```

`permission_group_ids`, `group_ids_with_any_permission`, `permission_user_ids`, and `user_ids_with_any_permission` return defensive array copies. Missing permissions return `[]`, not `nil`.

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

Models that include `AclTarget` also get visibility scopes:

```ruby
Board.with_acl_permission(guardian, "view")
Board.with_any_acl_permissions(guardian, %w[view edit manage])
```

Prefer these scopes for model index queries when they compose better with other filters. Use Guardian target-id helpers when the caller needs ids for more custom query construction.

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
- `.with_acl_permission(guardian, permission)`
- `.with_any_acl_permissions(guardian, permissions)`
- `.acl_target_key`, defaulting to `name`
- `.has_mandatory_acl?`
- `.acl_is_mandatory?(acl)`
- `.has_banned_acl?`
- `.acl_is_banned?(acl)`
- `mandatory_acl_as_expanded_list(owner)`

`AclTarget.acl_matches?(acl_a, acl_b)` is the shared comparator for mandatory and banned ACL matching. It normalizes `type` to symbols and compares `permission` as strings.

## Mandatory and Banned ACLs

Define `self.mandatory_acl` on the target class when some grants must always exist:

```ruby
def self.mandatory_acl
  [{ type: :group, id: Group::AUTO_GROUPS[:admins], permission: "manage" }]
end
```

Define `self.banned_acl` on the target class when specific grants must never be selectable or persisted:

```ruby
def self.banned_acl
  [{ type: :group, id: Group::AUTO_GROUPS[:anonymous_users], permission: "edit" }]
end
```

Mandatory entries are consumed by both backend writes and frontend rendering:

- `AccessControlList.inject_mandatory_acl(flattened_acl, target)` appends missing mandatory entries.
- `AccessControlListManager` calls that method before inserting rows.
- `flattened_list` marks matching entries with `mandatory: true`.
- `Site#access_control` exposes mandatory ACL metadata for registered targets.

Banned entries are consumed by both backend writes and frontend rendering:

- `AccessControlListManager` rejects submitted ACLs that match the target class's `banned_acl` via the `has_no_banned_acl` policy.
- `Site#access_control` exposes banned ACL metadata for registered targets.
- `DAccessControl` filters banned permission options for the matching grantee.

Keep mandatory and banned ACL metadata group-based unless the target flow has explicit user ACL UI and review coverage. Backend lookups can understand user ACL rows, but shared frontend editing is not complete.

## Stale References

`flattened_list` is defensive around stale data:

- Unknown `target_type` values are logged and skipped when no `for_target:` is provided.
- Deleted groups and users are skipped instead of raising while flattening.

This is a read-path fallback, not a substitute for validation. Validate group and user ids at the service/contract boundary, and rely on `Jobs::CleanupAclsForDeleted` to remove deleted grantee ids from persisted ACL rows.
