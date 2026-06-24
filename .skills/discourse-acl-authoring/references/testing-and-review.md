# Testing and Review Checklist

Use this reference when adding specs or reviewing ACL-backed features.

## Backend Specs

For target models:

- Include `AclTarget`.
- Cover `mandatory_acl` if the target defines one.
- Cover domain helper methods such as `anonymous_can_read?` or `can_write?` that wrap `permission_acl`.

For Guardian methods:

- Cover anonymous, logged-in, direct group membership, writer-implies-reader, and manager cases as applicable.
- Cover target-id list helpers when an index action scopes resources by ACL.
- If pseudo groups are involved, cover `granular_anonymous_and_logged_in_groups_permissions` behavior when relevant.

For services using `AccessControlListManager`:

- Creation with omitted `acl` persists mandatory ACLs.
- Creation with `acl: []` persists mandatory ACLs or fails closed when no mandatory ACL exists.
- Update with explicit `acl: []` replaces existing ACLs with mandatory ACLs.
- Update with a non-empty ACL replaces old rows and logs/records permission history if the feature has history.
- Unauthorized actors fail before the manager mutates ACL rows.
- Invalid group IDs fail at the service/contract boundary when user input can supply IDs.

For migration specs:

- Blank legacy arrays.
- Existing read/write/manage group values.
- Default setting fallback when no setting row exists.
- Raw setting rows that omit mandatory values.

## Frontend Specs

For `DAccessControl` consumers:

- Rendered permissions match target-specific labels/descriptions.
- Mandatory ACL from `site.access_control.mandatory_acl[targetKey]` appears and is locked.
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
- Does the UI `@aclTarget` string match the target's `acl_target_key`?
- Is ACL serialization limited to users who can manage the specific target?
- Are list/index queries using `guardian.target_ids_with_acl_permission` or `target_ids_with_any_acl_permissions` instead of ad hoc SQL?
- Are group IDs validated before persistence when they come from params?
- Are plugin target classes registered with `DiscoursePluginRegistry.register_acl_target_class`?
- Do tests cover anonymous users and pseudo-group semantics if `anonymous_users`, `logged_in_users`, or `everyone` can appear in ACLs?

## Known Sharp Edges

- `AccessControlListManager` currently assumes caller-side authorization.
- Group support is complete enough for current UI; user ACL support is not.
- `DAccessControl` injects mandatory rows for display but does not notify the parent on render.
- Mandatory ACLs from site settings need extra care in migrations because raw stored settings may omit `mandatory_values`.
- `flattened_list` dereferences group records, so stale group IDs can break serialization unless validated or cleaned up.
