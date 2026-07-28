# Testing and Review Checklist

Use this reference when adding specs or reviewing ACL-backed features.

## Backend Specs

For target models:

- Include `AclTarget`.
- Cover `mandatory_acl` if the target defines one.
- Cover domain helper methods such as `anonymous_can_read?` or `can_write?` that wrap `permission_acl`.
- Cover `.with_acl_permission` and `.with_any_acl_permissions` when index/list actions depend on the shared scopes.

For Guardian methods:

- Cover anonymous, logged-in, direct group membership, writer-implies-reader, and manager cases as applicable.
- Cover target-id list helpers when an index action scopes resources by ACL.
- If pseudo groups are involved, cover `granular_anonymous_and_logged_in_groups_permissions` behavior when relevant.

For services using `AccessControlListManager`:

- Creation with omitted `acl` persists mandatory ACLs.
- Creation with `acl: []` persists mandatory ACLs or fails closed when no mandatory ACL exists.
- Update with explicit `acl: []` replaces existing ACLs with mandatory ACLs.
- Submitted ACLs that match the target class's `banned_acl` fail the `has_no_banned_acl` policy.
- Update with a non-empty ACL replaces old rows and logs/records permission history if the feature has history.
- After a successful manager call, the target instance has been reloaded and should not retain a stale `permission_acl` cache.
- Unauthorized actors fail before the manager mutates ACL rows.
- Invalid group IDs fail at the service/contract boundary when user input can supply IDs.

For cleanup behavior:

- Destroying a group enqueues `:cleanup_acls_for_deleted`.
- `Jobs::CleanupAclsForDeleted` removes the group id from ACL rows.
- Destroying a user enqueues `:cleanup_acls_for_deleted`.
- `Jobs::CleanupAclsForDeleted` removes the user id from ACL rows.
- ACL rows with no remaining group or user ids are deleted.
- ACL rows that still have user ids are preserved.
- ACL rows that still have group ids are preserved.

For lookup objects:

- `Acl::Target#permission_group_ids` returns `[]` for missing permissions and a defensive copy for present permissions.
- `Acl::Target#group_ids_with_any_permission` replaces the older `multi_permission_group_ids` name.
- `Acl::Target#permission_user_ids` and `#user_ids_with_any_permission` return `[]` for missing permissions and defensive array copies for present permissions.
- `Acl::User#target_ids_with_permission` and `#target_ids_with_any_permissions` return defensive array copies.

For migration specs:

- Blank legacy arrays.
- Existing read/write/manage group values.
- Default setting fallback when no setting row exists.
- Raw setting rows that omit mandatory values.

## Frontend Specs

For `DAccessControl` consumers:

- Rendered permissions match target-specific labels/descriptions.
- Mandatory ACL from `site.access_control.mandatory_acl[targetKey]` appears and is locked.
- Banned ACL from `site.access_control.banned_acl[targetKey]` removes matching permission options for the matching grantee.
- Existing rows with the same group as a mandatory row are not duplicated.
- `onChange` writes updated ACL arrays into parent state.
- The final save payload includes the intended ACL array.

Use `.skills/discourse-writing-js-tests` for QUnit patterns.

## Review Checklist

Ask these questions during code review:

- Is every ACL write routed through `AccessControlListManager`?
- Does the caller authorize the actor before the manager can replace ACL rows?
- Does the service distinguish omitted ACL params from explicit empty ACL params when that matters?
- Are mandatory ACLs enforced in both backend writes and frontend display?
- Are banned ACLs enforced in backend writes and filtered from the frontend for matching grantees?
- Does the UI `@aclTarget` string match the target's `acl_target_key`?
- Is ACL serialization limited to users who can manage the specific target?
- Are list/index queries using `Target.with_acl_permission`, `Target.with_any_acl_permissions`, `guardian.target_ids_with_acl_permission`, or `target_ids_with_any_acl_permissions` instead of ad hoc SQL?
- Are group and user IDs validated before persistence when they come from params?
- Are plugin target classes registered with `DiscoursePluginRegistry.register_acl_target_class`?
- Do tests cover anonymous users and pseudo-group semantics if `anonymous_users`, `logged_in_users`, or `everyone` can appear in ACLs?
- Do tests cover stale group rows or missing plugin target classes if the code serializes ACLs that may outlive their original target or group?

## Known Sharp Edges

- `AccessControlListManager` currently assumes caller-side authorization.
- Backend user ACL support is partial: expansion, flattening, preloading, lookup helpers, matching scopes, and cleanup jobs handle `allowed_user_ids`, but shared UI authoring is not complete.
- `DAccessControl` remains group-first and does not provide complete user ACL editing yet.
- `DAccessControl` injects mandatory rows for display but does not notify the parent on render.
- `DAccessControl` filters banned permission options for UX, but hidden options are not authorization. The manager policy is the enforcement point.
- Mandatory ACLs from site settings need extra care in migrations because raw stored settings may omit `mandatory_values`.
- `flattened_list` skips stale group IDs, stale user IDs, and unknown target classes, so a missing row can disappear from serialized ACL output while cleanup or validation catches up.
