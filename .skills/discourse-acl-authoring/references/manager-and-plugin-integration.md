# Manager, Services, and Plugin Integration

Use this reference when writing ACL rows, creating an ACL-backed target model, registering plugin targets, or serializing ACLs from controllers/services.

## AccessControlListManager

`AccessControlListManager` is the standard write path for replacing a target's ACLs.

```ruby
AccessControlListManager.call(
  guardian:,
  params: {
    target: board,
    flattened_acl: flattened_acl,
    owner: DiscourseKanban::PLUGIN_NAME,
  },
) do |result|
  on_success do |previous_permissions:, new_permissions:|
    # optional history/event work
  end

  on_failure do
    fail!(I18n.t("plugin.target.errors.acl_update_failed"))
  end
end
```

Behavior:

- validates `target` and `owner`
- fetches previous target permissions
- injects mandatory ACLs into `flattened_acl`
- fails `has_no_banned_acl` if any final flattened ACL entry matches the target class's `banned_acl`
- fails `has_at_least_one_acl` if the final ACL list is empty
- destroys all current ACL rows for the target
- inserts expanded ACL rows
- logs a staff action with previous and new permission lookup data
- reloads the target after the transaction so `AclTarget#permission_acl` is rebuilt on the caller's instance

Important: the manager destructively replaces target ACL rows and does not currently authorize the actor itself. Authorize before calling it.

## Write Path Rules

- Call the manager even when the submitted ACL array is empty. Empty means "replace with mandatory ACLs if any"; skipping the manager leaves stale ACLs or creates ACL-less records.
- Do not mutate ACL rows manually from controllers. Use the manager from a service step.
- Pass a stable owner string, usually the plugin name constant.
- Keep side effects such as history rows, events, or MessageBus publishes outside the transaction unless they must roll back with the ACL write.
- When using `Service::Base`, follow `.skills/discourse-service-authoring`.

## Target Creation

For new target records with mandatory ACLs:

1. Authorize resource creation with a domain Guardian method.
2. Create the target.
3. Call `AccessControlListManager` with `flattened_acl: raw["acl"] || []`.
4. Fail the service if ACL creation fails.

This ensures mandatory ACL rows are inserted for API callers that omit `acl`.

For update flows, call the manager when ACL params are part of the contract. If ACL updates are optional, distinguish "key omitted" from "key present with empty array" deliberately.

## Plugin Target Registration

Plugin target classes must include `AclTarget` and be registered after initialization:

```ruby
after_initialize do
  DiscoursePluginRegistry.register_acl_target_class(DiscourseKanban::Board, self)
end
```

The registry is declared as `acl_target_classes` in `DiscoursePluginRegistry`. `Site#access_control` combines loaded core `AclTarget.target_classes` with plugin-registered classes and exposes mandatory ACLs by `acl_target_key`.

String registrations are allowed and resolved with `safe_constantize`; class registrations are preferred when the constant is available. Unresolved strings and registered classes that do not respond to `has_mandatory_acl?` are skipped from site metadata, with unresolved strings logged for debugging.

## Site Metadata

`SiteSerializer` includes `access_control`.

Shape:

```ruby
{
  mandatory_acl: {
    "DiscourseKanban::Board" => [
      { type: :group, id: Group::AUTO_GROUPS[:admins], permission: "manage" },
    ],
  },
  banned_acl: {
    "DiscourseKanban::Board" => [
      { type: :group, id: Group::AUTO_GROUPS[:anonymous_users], permission: "edit" },
    ],
  },
}
```

The key is `target_class.acl_target_key`, which defaults to the class name. If a frontend passes `@aclTarget`, it must match this key exactly.

`mandatory_acl` and `banned_acl` are both always present in the serialized `access_control` payload. Each map only includes target classes that define non-empty metadata for that ACL type.

## Serializing Target ACLs

Use `AccessControlList.where(target: target).flattened_list` when returning ACLs to a client that edits them.

Only include ACL details for actors who can manage that specific target. Avoid using a broad global capability when per-target ACL management exists.

```ruby
def payload(target, include_acl:)
  {
    id: target.id,
    can_manage: guardian.can_manage_target?(target),
    acl: include_acl ? AccessControlList.where(target: target).flattened_list : nil,
  }
end
```

Use `TargetClass.with_acl_permission(guardian, permission)` or `TargetClass.with_any_acl_permissions(guardian, permissions)` for index scopes where the user should see targets reachable through ACLs. Use `guardian.target_ids_with_any_acl_permissions(TargetClass, permissions)` only when the id array is the cleaner interface for a custom query.

## Deleted Grantee Cleanup

`Group#clear_acls` and `User#clear_acls` enqueue `Jobs::CleanupAclsForDeleted` after a grantee is destroyed. The job removes the deleted group id from `allowed_group_ids` and/or the deleted user id from `allowed_user_ids`, updates `updated_at`, and deletes ACL rows only when both arrays are empty.

## Migrations

When migrating legacy permission columns into ACLs:

- Preserve previous semantics intentionally and document any security-tightening changes.
- Union mandatory ACL values into migrated rows; raw site setting rows may not include `mandatory_values`.
- Use `Group::AUTO_GROUPS` values or stable numeric IDs only when loading the Rails constants is unsafe in the migration context.
- Cover blank legacy arrays, customized group lists, and default setting fallbacks in migration specs when possible.

## Current Limitations

- `AccessControlList.expand_list_for_bulk_insert`, `flattened_list`, `preload_allowed`, lookup objects, matching scopes, and cleanup jobs now handle both group and user ACL rows.
- `DAccessControl` remains group-first: it does not yet provide user picking or complete user ACL editing, even though backend rows can contain `allowed_user_ids`.
- `flattened_list` skips missing groups, missing users, and unknown target classes defensively. Validate group and user IDs at the service/contract boundary where user input enters; do not rely on read-path skipping as data hygiene.
- The manager has caller-side authorization. Future core work may add a target policy hook; until then, do not expose it directly to untrusted callers.
