# ACL Replacement and Plugin Integration

Use this reference when writing ACL rows, creating an ACL-backed target model, registering plugin targets, or serializing ACLs from controllers/services.

## AccessControlList::Apply

`AccessControlList::Apply` is the standard write path for applying a target's complete ACL configuration. It resolves the registered target internally and replaces ACL rows and writes audit records in a transaction.

```ruby
AccessControlList::Apply.call(
  guardian:,
  params: {
    acl_target_type: board.class.name,
    acl_target_id: board.id,
    acl_entries: flattened_acl,
    source: Boards::PLUGIN_NAME,
    initial_owner_user_id: board.created_by_id,
    owner_user_ids: raw["owner_user_ids"],
  },
) do |result|
  on_success do |current_acl:, replacement:|
    # optional history/event work
  end

  on_failure do
    fail!(I18n.t("plugin.target.errors.acl_update_failed"))
  end
end
```

Behavior:

- validates the target identity, nested ordinary ACL entries, grantee identities, and `source`
- resolves the target only from registered ACL target classes
- reads previous target permissions directly from stored ACL rows
- resolves `initial_owner_user_id` only when the target has no valid stored owner and creates the initial owner grant from that user
- preserves existing owners when `owner_user_ids` is omitted; when supplied, treats it as the complete desired owner set
- allows any valid user to be the initial owner, but requires the actor to be an owner in the currently stored ACL or an admin whenever `owner_user_ids` is supplied; the actor does not need to remain in the requested set
- validates that every requested owner is a user and at least one owner remains
- rejects every `owner` entry in `acl_entries`; `owner_user_ids` is the only ownership mutation channel
- removes owners from lower direct user grants so one grantee does not render multiple ACL rows
- injects mandatory ACLs into `acl_entries`
- resolves the target class's `ACL_PERMISSIONS` constant, including inherited declarations; a missing declaration raises `NameError`
- fails `has_valid_permissions` if any final flattened ACL permission is absent from `ACL_PERMISSIONS.values`
- fails `has_no_banned_acl` if any final flattened ACL entry matches the target class's `banned_acl`
- destroys all current ACL rows for the target
- inserts expanded ACL rows
- logs ordinary permission changes separately from owner additions and removals
- reloads the target after the transaction so `AclTarget#permission_acl` is rebuilt on the caller's instance

Important: the service destructively replaces target ACL rows. Authorize ordinary permission changes before calling it; ownership changes are additionally authorized inside the service.

The service's `source` string is ACL row provenance, not target ownership. Pass the authoritative initial target owner's id separately as `initial_owner_user_id`; the service resolves the user model internally when the target has no owner. Use `owner_user_ids` only as the dedicated ownership mutation channel. Omit it to preserve owners and pass the complete desired set when a current owner or admin changes ownership. On an ownerless target, only an admin can supply `owner_user_ids`; a non-admin initial owner must add co-owners in a later call after ownership exists.

## Write Path Rules

- Call the replacement service even when the submitted ACL array is empty. Empty means "replace with mandatory ACLs and owners"; skipping it leaves stale ACLs or creates ownerless records.
- Do not mutate ACL rows manually from controllers. Use the replacement service from a service step.
- Pass a stable source string, usually the plugin name constant.
- Keep side effects such as history rows, events, or MessageBus publishes outside the transaction unless they must roll back with the ACL write.
- When using `Service::Base`, follow `.skills/discourse-service-authoring`.

## Target Creation

For new target records with mandatory ACLs:

1. Authorize resource creation with a domain Guardian method.
2. Create the target.
3. Call `AccessControlList::Apply` with the target's type and id plus `acl_entries: raw["acl"] || []`.
4. Pass the authoritative initial user's id as `initial_owner_user_id`; this may be any valid user. Do not trust an owner entry from `raw["acl"]`. Only an admin can also supply `owner_user_ids` while the target is still ownerless.
5. Fail the service if ACL creation fails.

This ensures mandatory ACL rows are inserted for API callers that omit `acl`.

For update flows, call the replacement service when ACL params are part of the contract. If ACL updates are optional, distinguish "key omitted" from "key present with empty array" deliberately.

## Plugin Target Registration

Plugin target classes must include `AclTarget` and be registered after initialization:

```ruby
after_initialize do
  DiscoursePluginRegistry.register_acl_target_class(Boards::Board, self)
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
    "Boards::Board" => [
      { type: :group, id: Group::AUTO_GROUPS[:admins], permission: "manage" },
    ],
  },
  banned_acl: {
    "Boards::Board" => [
      { type: :group, id: Group::AUTO_GROUPS[:anonymous_users], permission: "edit" },
    ],
  },
}
```

The key is `target_class.acl_target_key`, which defaults to the class name. If a frontend passes `@aclTarget`, it must match this key exactly.

`mandatory_acl` and `banned_acl` are both always present in the serialized `access_control` payload. Each map only includes target classes that define non-empty metadata for that ACL type.

## Evaluating Permission Loss Before Save

`POST /access-control/evaluate.json` calls `AccessControlList::EvaluateModification` with:

```json
{
  "target_type": "Plugin::Target",
  "target_id": 123,
  "new_acl": []
}
```

The service resolves `target_type` from `Site.access_control_target_classes`, injects the target class's mandatory ACL entries, and calculates which proposed entries apply to the current user through direct user grants or group membership. Evaluation fails when either:

- the current user would have no permission after the change; or
- the current user would lose any permission declared by `loss_warning_permissions`.

The first case uses `access_control_list.errors.user_will_not_have_permission` for an existing target and `access_control_list.errors.user_will_not_have_permission_on_create` when `target_id` is omitted. For configured loss warnings, define target-specific server translations for both editing and creation:

```yaml
en:
  access_control_list:
    errors:
      "Plugin::Target_user_will_lose_permission": "You will no longer be able to manage this target. Continue?"
      "Plugin::Target_user_will_lose_permission_on_create": "If you create this target with these permissions, you will not be able to manage it. Continue?"
```

The suffixes are `#{target_class.acl_target_key}_user_will_lose_permission` and `#{target_class.acl_target_key}_user_will_lose_permission_on_create`. Keep these translations in the plugin when the ACL target is plugin-owned.

The service evaluates only the proposed ACL. It does not load the target or compare the proposal with persisted ACL rows. `target_id` only selects edit wording when present; omitting it selects creation wording. Treat “loss” as an inference that the authorized editor already holds the configured permission.

This endpoint evaluates the proposed ACL for confirmation UX; it does not authorize access to the target or replace enforcement in the actual write service. Browser confirmation is not passed as proof to `AccessControlList::Apply`, so an API client can bypass the prompt. If confirmation must be server-enforced, extend the write contract and re-evaluate there before mutation.

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

When an index needs ACL grantee details for every target, flatten one relation for the whole collection and group the result before serialization. Do not query `AccessControlList` from each serializer instance.

```ruby
owners_by_target_id =
  AccessControlList
    .with_permission(targets, Acl::Permissions::OWNER)
    .flattened_list
    .group_by { |entry| entry[:target_id] }

serialize_data(targets, TargetSerializer, owners_by_target_id:)
```

`flattened_list` batch-loads the referenced users and groups. Pass the grouped entries through serializer options so adding targets does not add ACL or grantee queries.

## Deleted Grantee Cleanup

After the user row is destroyed, `User#reassign_acl_ownership` calls `AccessControlList::ReassignDeletedUserOwnership` synchronously in the destruction transaction, before `clear_acls`. The callback passes `user_id`, `username`, and `deleted_at` (`Time.current`) as a snapshot; the service does not look up the deleted user. The service is restricted to the system actor. It finds every stored owner ACL containing the departing user's ID and chooses one random active, unsuspended real admin other than that user for all targets. If none exists, ownership falls back to the system user.

The handoff replaces only the departing owner, preserves co-owners and `source`, deduplicates the new owner, and removes their redundant lower direct grants. This specialized write path operates on stored target identities without loading target classes, so disabled plugins do not prevent deletion. Ownership changes and audit records remain in the deletion transaction. Any failure rolls back deletion. Each transferred target gets an `assume_access_control_ownership` staff action with the recipient admin as actor and target user, the ACL target as subject, and snapshot values `deleted_user_id`, `deleted_username`, and ISO 8601 `deleted_at` in context. Quiet deletions still log the ownership handoff.

`Group#clear_acls` and `User#clear_acls` enqueue `Jobs::CleanupAclsForDeleted` after a grantee is destroyed. The job removes the deleted group id from `allowed_group_ids` and/or the deleted user id from `allowed_user_ids`, updates `updated_at`, and deletes ACL rows only when both arrays are empty. It skips user cleanup when that user ID currently exists, protecting restored records from stale jobs; group cleanup still runs if supplied in the same job.

Users are hard-deleted and have no normal per-account restoration flow. The staged-user CSV import creates accounts with newly assigned database IDs, so it does not reclaim transferred ownership. Anonymization retains the user ID and ownership. User merging deletes the source through `UserDestroyer`, so the same admin handoff applies. This lifecycle prevents new orphaned ownership; it does not backfill targets whose former owner rows were already removed.

## Current Limitations

- `AccessControlList.expand_list_for_bulk_insert`, `flattened_list`, `preload_allowed`, lookup objects, matching scopes, and cleanup jobs now handle both group and user ACL rows.
- `DAccessControl` supports user/group search and user grants. Persisted owner rows render after mandatory rows without a mandatory badge, with the Owner control disabled unless the actor can manage owners. Class-level mandatory ACL injection remains group-first; targets with other mandatory user grants need explicit UI support.
- `flattened_list` skips missing groups, missing users, and unknown target classes defensively. Validate group and user IDs at the service/contract boundary where user input enters; do not rely on read-path skipping as data hygiene.
- Ordinary permission authorization remains at the caller boundary; the replacement service authorizes ownership changes itself. Do not expose it directly to untrusted callers.
