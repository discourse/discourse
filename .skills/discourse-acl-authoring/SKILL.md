---
name: discourse-acl-authoring
description: Use when creating, editing, or reviewing Discourse access-control-list features built on AccessControlList, AclTarget, Guardian ACL helpers, AccessControlListManager, mandatory_acl, banned_acl, Site access_control metadata, plugin ACL target registration, or the DAccessControl UI component.
---

# Discourse ACL Authoring

Use this skill before adding or reviewing ACL-backed resource permissions in Discourse core or plugins.

## Workflow

1. Identify the target resource and desired permission vocabulary. Prefer simple strings such as `view`, `edit`, and `manage`, but confirm the target's domain semantics.
2. Read [references/backend-model.md](references/backend-model.md) when touching `AccessControlList`, `AclTarget`, `Acl::Target`, `Acl::User`, `Guardian`, `User#permission_acl`, or target visibility queries.
3. Read [references/manager-and-plugin-integration.md](references/manager-and-plugin-integration.md) when writing ACLs, creating target models, registering plugin target classes, serializing ACLs, or integrating services/controllers.
4. Read [references/frontend-d-access-control.md](references/frontend-d-access-control.md) when using or customizing `DAccessControl`.
5. Read [references/testing-and-review.md](references/testing-and-review.md) when adding specs or reviewing an ACL feature.
6. Also load `.skills/discourse-service-authoring` for `Service::Base` changes, `.skills/discourse-writing-rspec-tests` for RSpec, and `.skills/discourse-writing-js-tests` for QUnit.

## Non-Negotiables

- Put authorization at the caller boundary before `AccessControlListManager.call`; the manager is a destructive replacement service and currently assumes the caller already authorized the actor.
- Always call `AccessControlListManager` for writes, including empty submitted ACL arrays, so mandatory ACLs are injected and old rows are replaced intentionally.
- Treat `AccessControlList.flattened_list` as the API shape for UI/client payloads and `AccessControlList.expand_list_for_bulk_insert` as the DB insert shape.
- Use Guardian ACL helpers or `AclTarget` visibility scopes for checks and target scopes instead of hand-querying ACL tables in controllers.
- Register plugin ACL targets with `DiscoursePluginRegistry.register_acl_target_class` so `Site#access_control` exposes mandatory and banned ACL metadata to the frontend.
- Treat `banned_acl` as a server-enforced restriction. `DAccessControl` hides banned permission choices for UX, but `AccessControlListManager` must still reject submitted banned entries.
- Do not claim user ACL support is complete. Backend support is partially wired for `allowed_user_ids` in expansion, flattening, preloading, lookup helpers, matching scopes, and cleanup jobs, but `DAccessControl` remains group-first and does not yet provide complete user ACL editing.

## Local Anchors

- Model and relation API: `app/models/access_control_list.rb`
- Target concern: `app/models/concerns/acl_target.rb`
- Permission lookup objects: `lib/acl/target.rb`, `lib/acl/user.rb`
- Guardian helpers: `lib/guardian.rb`
- User ACL cache: `app/models/user.rb`
- Write manager: `app/services/access_control_list_manager.rb`
- Deleted grantee cleanup: `app/jobs/regular/cleanup_acls_for_deleted.rb`, `app/models/group.rb`, `app/models/user.rb`
- Site metadata: `app/models/site.rb`, `app/serializers/site_serializer.rb`
- Frontend component: `frontend/discourse/app/ui-kit/d-access-control.gjs`
- Core specs: `spec/models/access_control_list_spec.rb`, `spec/models/concerns/acl_target_spec.rb`, `spec/lib/acl/target_spec.rb`, `spec/jobs/regular/cleanup_acls_for_deleted_spec.rb`, `spec/services/access_control_list_manager_spec.rb`, `spec/serializers/site_serializer_spec.rb`, `frontend/discourse/tests/integration/components/d-access-control-test.gjs`
- Plugin consumer example: `plugins/discourse-kanban` or the external `discourse-kanban` checkout when present.
