# Multiple topic assignments implementation plan

This plan extends the behavior traced in [Topic assignment behavior and constraints](topic-assignments.md). It preserves existing replacement callers while introducing explicit operations for managing multiple topic assignments. Names and API routes below are proposed implementation choices.

## Implementation notes

The implementation uses the four OP mockup states as its display baseline: one or multiple topic assignments, with or without per-assignee notes. It extends the existing `AssignedToFirstPost`, `TopicAssignments`, `EditTopicAssignments`, topic footer dropdown, list-action dropdown, and Boards components. No new UI components are introduced. The editor uses core FormKit collections, the existing user/group chooser, buttons, and avatar helpers. Notes are plain escaped text.

The feature setting is `assign_allow_multiple_topic_assignees`, disabled by default. The hidden combined limit is `assign_max_assignments_per_topic`, defaulting to 20. Post targets remain singular. When the feature is off, single-assignee topics keep the existing editor; topics retaining multiple assignments remain visible and can be edited or reduced. Additions to those multi-assignee topics are blocked. This preserves data while the final disabling policy remains open for later review.

`DiscourseAssign::Assignments::Replace` implements the collection mutation service. The add, per-assignment edit, and per-assignment removal controller actions build versioned desired sets and use that service; existing `Assigner` entry points retain singleton replacement and target-clearing semantics. Full-list saves require the editor version and reject stale updates with 409. Empty JSON assignment arrays clear only direct topic assignments. Existing inactive user rows are retained for lifecycle restoration.

The new routes are the GET/PUT/POST topic collection and PATCH/DELETE assignment routes described below, and are included in the existing assign API-key scope. Editor snapshots and mutations synchronize on the topic; affected users are locked in ID order for workload checks. Collection reads preload assignees. Legacy scalar readers use a stable representative, while new UI reads use the full collection.

The staged index migrations preserve post uniqueness and topic-group uniqueness while removing universal target uniqueness after deployment. Collection writes check that the old index has been removed. No existing assignment rows are backfilled or discarded. A moved post keeps its Post target if converting it would collide with a destination topic assignment; assignments exceeding destination capacity or eligibility are retained inactive.

Verification covers the assignment Ruby suite, real-backend system flows, affected Boards and AI integrations, the full plugin frontend suite, TypeScript checks, and the regenerated database schema. Screenshot review confirmed the OP notes, existing footer dropdown, and existing modal; avatar images depend on the local image-processing environment.

## Requirements and design boundaries

Agreed behavior:

- Gate multiple direct topic assignments behind a site setting, disabled by default.
- Allow multiple users and at most one group on a topic, including a direct user who also belongs to that group.
- Keep individual posts limited to one user or group.
- Keep notes and statuses per assignment.
- Edit the complete direct topic assignee list in the modal and allow removing an individual assignment from the topic display.
- Replace the hard-coded five-assignment limit with a hidden setting defaulting to 20 active assignment records across the topic and its posts. A group assignment counts as one record.
- Preserve replacement behavior for existing single-assignee API, automation, workflow, and integration callers. Adding requires an explicit operation.
- Notify overlapping direct/group recipients only when they newly become responsible, while retaining separate assignment records.

The row-per-assignee modal is provisional and requires design review. Behavior when disabling the setting after multiple assignments exist is deliberately unresolved. Neither decision should be inferred from implementation convenience. The disabling policy must be settled before enabling the feature in production; preparation work can proceed first.

## Settings

Add to `config/settings.yml` with descriptions in `config/locales/server.en.yml`:

| Proposed setting | Configuration | Behavior |
| --- | --- | --- |
| `assign_allow_multiple_topic_assignees` | Boolean, false, client exposed, refresh clients | Allows the new topic collection operations. Requires the assignment plugin and completed schema rollout. |
| `assign_max_assignments_per_topic` | Hidden integer, 20, minimum 1 | Replaces `ASSIGNMENTS_PER_TOPIC_LIMIT` for all topic and post writers, including when multiple topic assignments are disabled. |

Enforce both server-side. Return the effective limit/capability with the editor data if needed rather than exposing the hidden setting globally. Update failure messages to interpolate the setting value. Keep `max_assigned_topics` as the separate per-user workload setting.

Recommended behavior when a limit is reduced below existing usage: preserve existing rows and allow removals and details edits; reject changes that increase an already excessive count. Explicitly test net replacements at capacity. Apply the cap to reactivation as well as creation, with a defined failure path instead of silently dropping retained assignments.

## Database migrations and deployment

Retain the existing `assignments` table and one row per assignee. No assignee join table, note/status relocation, or existing-assignment backfill is needed.

Retain the unique `unique_target_and_assigned` index on `(assigned_to_id, assigned_to_type, target_id, target_type)`. It prevents assigning the same target to the same user/group twice, including inactive rows.

Replace the universal unique target index with these constraints:

| Index | Predicate | Purpose |
| --- | --- | --- |
| Unique `(target_id, target_type)` | `target_type = 'Post'` | Preserve one retained assignment per post |
| Unique `(target_id, target_type)` | `target_type = 'Topic' AND assigned_to_type = 'Group'` | Preserve at most one retained group assignment per topic |
| Nonunique `(target_id, target_type)` | None | Support target lookups after removing the universal unique index |

Keep the existing topic and assignee indexes. The partial constraints deliberately include inactive rows, matching existing retained-row behavior. Replacing an inactive group with a different group must remove the old group slot; assigning the same user again must reuse/reactivate or explicitly replace their retained row rather than inserting a duplicate.

Deploy in stages:

1. **Prepare constraints and code.** Generate plugin migrations with the repository generators. Add the replacement indexes before removing the old index. For concurrent index operations, use dedicated transaction-disabled migrations, remove any same-named invalid/retry index before creating it, and follow SafeMigrate rules. Do not mix column/table changes into those migrations.
2. **Deploy collection-aware code with the feature unavailable.** Migrate internal writers to the common mutation path, but retain the old unique index through the overlap with old processes. Readers and jobs must already tolerate multiple rows before any site can create them.
3. **Remove the old universal unique index after old processes retire.** Use a plugin post-deploy migration. Prevent enabling collection writes while that index remains, including deployments that skip post-deploy migrations. Verify capability invalidation after post-deploy completion; avoid a stale boot-time schema check.
4. **Enable only after the release is ready.** Confirm updated web and job workers, integration compatibility, and the setting-disable policy. Existing sites remain off by default.

Regenerate the structure dump and annotations and run `bin/rake db:check_structure_dump`. Migration specs must verify existing data preservation, each partial unique constraint, duplicate-assignee protection, and clean installation as well as upgrade behavior.

Rolling back the schema after multi-assignment data exists cannot recreate universal target uniqueness without losing data. Do not implement a destructive rollback that chooses an assignee arbitrarily. Code rollback to a singular reader/writer version also needs an explicit operational plan.

## Models and read compatibility

Update `lib/discourse_assign/topic_extension.rb`:

- Add a direct `has_many :assignments, as: :target` association with dependent cleanup.
- Add a distinctly named association for all topic-owned rows through `topic_id`, including post targets. Use it for total counts and lifecycle operations.
- Replace internal singular reads with explicit collection operations. Do not let a retained compatibility reader become a write path.

Keep `Post#assignment` singular. Update `Assignment` scopes/helpers to distinguish direct topic assignments, post assignments, active rows, and assignee type. Put row-owned status/default/type validation in the model; put actor permissions and aggregate policies in the mutation service.

For legacy read contracts, propose one deterministic representative assignment, ordered by assignment ID, preferring active rows for active display. All legacy scalar fields must derive from that same row. This is a compatibility projection, not a new product concept of a primary assignee. New UI and correctness-sensitive checks must use the collection.

Inventory and migrate callers of `topic.assignment`, `create_assignment!`, `preload_assigned_to`, and association-based joins. Retain only the compatibility surface genuinely needed by existing integrations; dependent destruction must have one authoritative path. Clear preloaded assignment state after mutations.

## Services and mutation semantics

Use `Service::Base` following the core service documentation. Proposed operations are `DiscourseAssign::Assignments::Add`, `Update`, `Remove`, and `Replace`, sharing one aggregate validation/persistence mechanism. A collection save uses `Replace`; existing `Assigner#assign` invokes replacement with a singleton set. Existing `Assigner#unassign` clears assignments on its target. The existing public `Assigner` entry points remain for the agreed caller compatibility; they must not retain an independent persistence implementation.

| Operation | Meaning |
| --- | --- |
| Add | Add an assignee to a topic without removing anyone; require the feature setting |
| Update by assignment ID | Edit that assignment's note/status without changing its identity |
| Remove by assignment ID | Remove exactly that record |
| Replace topic set | Persist the desired complete direct topic list; preserve unchanged rows |
| Legacy assign | Replace all assignments on the target with the requested user/group |
| Legacy unassign | Clear the target's assignments; topic unassignment leaves post targets intact |

Service flow:

1. Validate payload shape, lengths, target and assignee types, and required fields. Obtain the acting user through a Guardian dependency, not request-supplied actor IDs.
2. Load the visible target and verify assignment permissions. Resolve visible users/groups and check target visibility for every recipient, including all group members and PM participation rules.
3. Serialize mutations on the owning topic, including legacy calls and post writes. Reload current rows inside the lock, check an optional expected-version token, and compute the desired final set and actual changes.
4. Validate the final state: unique assignees, no more than one group, post cardinality, feature setting, total active cap, workload limits, note/status validity, and retained inactive slots. Details edits/removals must remain possible when an existing assignee later loses eligibility.
5. Apply the change in a transaction. Preserve IDs, assigners, creation timestamps, notes, and statuses for retained assignments unless explicitly edited. Treat an empty string as clearing a note; distinguish omitted values from explicit null/empty values. Reject the whole collection save when any entry is invalid.
6. After commit and outside the mutation lock, dispatch notifications, emails, MessageBus refreshes, moderator activity, webhooks, and events from the committed changes. No side effect should be sent for a failed transaction. Make async reconciliation retry-safe and tolerate rows removed before a queued job executes.

PM invitations need their own explicit handling: perform non-mutating validation before invitations, coordinate required database invitation writes with the assignment transaction where supported, and defer external alerts until commit. A failed batch must not leave unrelated invitations behind through the current invite-before-validation path.

Fix the missing `assigned_to_type = 'User'` workload predicate when centralizing checks. Preserve group and self-assignment exemptions. Workload enforcement counts active direct topics, not post rows; shared group membership alone does not create a direct-user workload assignment. For concurrent assignments to one user across different topics, use a consistent locking order for affected user workload checks as well as topic mutations; topic locking alone cannot enforce that limit.

## Controllers and API contracts

Keep the existing `/assign/assign` and `/assign/unassign` routes, parameters, confirmation response shape, API-key scope, and failure behavior. A singleton replacement must remove the other direct assignees rather than merely replacing the compatibility representative.

Proposed collection routes under the assignment engine:

| Route | Purpose |
| --- | --- |
| `GET /assign/topics/:topic_id/assignments` | Load authorized editor data, assignments, capabilities, effective cap, and version |
| `PUT /assign/topics/:topic_id/assignments` | Atomically replace the complete direct topic set |
| `POST /assign/topics/:topic_id/assignments` | Explicitly add one direct topic assignee |
| `PATCH /assign/assignments/:id` | Edit one record's note/status |
| `DELETE /assign/assignments/:id` | Remove one record; return 204 |

Use explicit nested parameter whitelists. Verify assignment IDs belong to the authorized topic/target. Never authorize solely from possession of an assignment ID. Allow only topic targets in the add/set contract; post operations retain the existing single-assignee behavior.

The collection save carries an expected-version token derived from the editor state. Compare under the topic lock and return 409 for a stale full-list save rather than silently erasing another user's additions. Return canonical assignments and a fresh token on successful add/update/set operations. Serialize 201 for creation and 200 when returning updated data.

Scope the new full-set save to direct topic assignments. It must never delete post assignments because they were omitted. Retain existing post editing as a separate target flow; if final design combines topic and post edits under one Save button, extend the aggregate request with explicit post changes and commit them together rather than reinstating sequential partial saves.

## Serializers and live updates

Introduce an assignment serializer with real assignment ID, target type/ID, assignee type/entity, note, and optional status. Include assigner/timestamps only where the client needs them. Permission-gate the full collection and all details using the existing assignment visibility rules; hidden post targets must not leak through aggregate payloads.

Expose a `topic_assignments` array for direct topic assignments. Keep `indirectly_assigned_to` for singular post assignments. Retain existing scalar fields as the deterministic legacy projection during the compatibility period. Update the appropriate frontend model Fields interfaces and type tests wherever serializer shapes change.

Update batch preloading for topic views, topic lists, search, bookmarks, suggested/flagged topics, admin assigned listings, and Boards. Group direct rows by target instead of `find`/`index_by` selecting one. Avoid per-assignment N+1 queries by preloading assignees and targets. Do not load assignment details for viewers who cannot access them.

For live updates, prefer one authorized topic-assignment refresh after a committed operation, returning a canonical snapshot/version rather than letting each event overwrite scalar fields. Coalesce batch refreshes and ignore older responses. Keep legacy MessageBus behavior available for singular clients during rollout; avoid putting an ambiguous multi-assignee payload on the old event contract. Individual removal must identify the assignment, not just the target.

## Notifications and activity

Proposed reconciliation unit: one user receiving direct topic responsibility, through a user assignment or the topic's assigned group. Keep post-assignment notification behavior separate in this change; confirm this boundary before implementation.

Compute recipients before and after a committed change:

- Newly responsible: create one notification and send configured alerts/email, retaining self-assignment read behavior.
- Still responsible through another assignment: preserve read/dismissal state and do not alert again merely because the source changed.
- No longer responsible: remove the topic-assignment notification.

The current notification JSON points to one assignment ID. Deduplication therefore needs more than skipping creation. When the referenced assignment is removed but another still confers responsibility, reconcile the notification to a deterministic surviving assignment without resetting its read state. If all relevant assignments disappear, delete it. Ensure a delayed old unassign job cannot delete the reconciled notification.

Use the same reconciliation for group membership changes, group destruction, deactivation/reactivation, and ordinary edits. Recheck current responsibility in queued jobs; process duplicate and out-of-order jobs safely. Preserve `should_notify: false`/`silenced_assignments` semantics so silent rows do not accidentally generate a later alert. Keep unchanged note/status updates from generating new assignment alerts.

Do not merge or delete existing historical notification rows merely by migration. Reconcile affected recipients through the new path. Add tests for direct-then-group, group-then-direct, removing either source, membership changes, read notifications, silenced assignments, retries, and final removal.

Moderator activity, webhook payloads, and workflow events remain assignment-specific. Emit activity for actual additions, removals, and detail changes, without an artificial reassign for every unchanged row in a modal save. Preserve existing legacy event/webhook contracts and test replacement ordering; where richer collection context would change an existing contract, add a new event or version rather than repurposing its fields.

## Frontend and design work

Update `models/assignment.js` to use real record IDs rather than `0` for topics or post numbers for identity. Give unsaved draft rows local stable keys. Update topic model helpers to read all direct assignments, deduplicate users by user identity, and keep user/group identity distinct.

Build the new modal with FormKit and ui-kit primitives. Pending design review, show an add-assignee chooser followed by one row per assignment with its own note/status controls and remove action. Prevent duplicate choices and a second group, display the remaining combined capacity, and preserve drafts on errors. Disable repeated submissions and handle 409 with a refresh/review flow that does not discard the draft silently. Keep single-assignee UI when the feature is off, subject to the deferred disabling policy.

Update these surfaces together:

- First-post assignment summary and topic header/footer/menu actions: show all direct assignees and individual removal; distinguish clearing all from removing one.
- Topic tags/avatars, search results, and bookmarks: render the collection without implying one primary assignee; apply an accessible overflow treatment if needed.
- Profile Assigned list and its action menu: show each topic once, offer the correct assignee-specific actions, and preserve other assignees when removing one.
- User-menu assignment notifications: consume the reconciled notification behavior while retaining unread and bump-time ordering.
- Boards: retain its existing assignment collection support, add real assignment IDs to its payload, switch `unassignTarget` to individual removal, and open the collection editor. Otherwise clicking one topic assignee's removal would clear every direct assignment. Leave floater-card assignment behavior unchanged.

Use translated sentence-case strings, BEM classes and theme palette variables, keyboard/focus management, accessible row labels, and responsive layouts. Validate Foundation/Horizon in light/dark modes on desktop/mobile. Final modal layout, overflow, and destructive-action wording remain design work.

## Queries, lifecycle, and integrations

Use assignment existence or topic-ID subqueries for assigned/unassigned filters. Audit joins, sorting, group totals, pagination and search for duplicated topics after multiple matching rows become possible. Keep distinct-topic counts separate from assignment record counts. Align recent-assignee suggestions and reminders with active direct-user workload semantics.

Update close/reopen, archive/inbox, post deletion/recovery/move, group membership/destruction, and solved/unsolved status handlers to operate on the correct collections. Reactivation must preserve the group slot and aggregate cap. Converting a moved post assignment to a topic assignment must check duplicate assignee, group cardinality, capacity and destination permissions; do not allow a raw row update to bypass the service.

Preserve replacement semantics for bulk assign, mention-based autoassignment, random assignment, AI tools, Boards column mutation/carry-over, and the `:assign_topic` event. Ensure unassign-all paths clear the intended scope without unintentionally deleting post assignments. Additive automation behavior is not part of this change.

Workflow assignment checks should test collection membership, not the representative row. Existing event-trigger schemas already describe an individual assignment and can continue to do so. Keep saved node versions and scalar outputs working; a new collection output or changed meaning of `previously_assigned` requires a new node version. Pin old schema behavior in specs rather than silently converting a scalar to an array.

## Delivery sequence and verification

| Change set | Scope | Completion evidence |
| --- | --- | --- |
| 1. Foundation | Partial indexes, collection reads, stable compatibility projection, hidden cap, centralized legacy writes | Existing single-assignee behavior passes; fresh/upgrade schema checks pass; multiple writes still unavailable |
| 2. Mutation APIs | Services, cardinality/cap policies, atomic set operations, expected versions, real assignment IDs | Request/service/model tests for permissions, stale saves, rollback and concurrency |
| 3. Notifications and lifecycle | Recipient reconciliation, silent assignments, deferred effects, close/reopen and group/post events | No duplicate alerts, no dropped surviving responsibility, no effects on rollback; lifecycle regression tests pass |
| 4. UI and integrations | Collection editor/display, list actions, Boards, serializers/types, workflow/AI/bulk compatibility | UI tests and cross-plugin specs pass; design review and theme/mobile checks complete |
| 5. Activation | Post-deploy index removal, final disabling policy, capability checks and documentation | Safe staged upgrade verified; feature off/on behavior verified; explicit production enablement possible |

Index preparation and removal may ship in different releases. Do not enable before all change sets are complete. The old unique index can remain during backend/UI development; multi-row test fixtures require a database with the replacement schema.

Required behavioral coverage includes setting-off single assignment; multiple users plus one group; rejection of duplicate users/second group; singular posts; 20/21 combined assignments; configurable limits; replacements at capacity; concurrent additions and user workload limits; stale set saves; notes/status edits and clearing; failed batch rollback; private/category-scoped access; group PM invitations; all notification overlap cases; lifecycle reactivation; topic-list deduplication/pagination; unchanged legacy replacement/clear semantics; and Boards individual removal.

Use focused `LOAD_PLUGINS=1 bin/rspec` runs while developing, then the assignment plugin suite and affected Boards, AI, workflow, and automation specs. Run relevant `bin/qunit` component/acceptance tests, type checks when model types change, and schema dump checks. Follow the RSpec/JS test skills during implementation and the service skill's delegated service-spec workflow where applicable. Run `bin/lint --fix` once on the completed changed-file set before handoff.

## Decisions to close before activation

1. Finalize the modal/topic-display design, including post-edit placement and removal wording.
2. Decide what happens when the setting is disabled with multiple assignments already present. No migration or settings callback may silently discard assignees in the meantime.
3. Confirm direct-topic recipient reconciliation scope, the notification representative/rebinding behavior, and email deduplication. Post notifications are proposed to retain existing behavior.
4. Confirm the proposed legacy scalar read projection and versioned workflow behavior where a scalar cannot express the full set.

The implementation can start with the schema/read foundation and mutation service work while these product/design decisions remain open. Activation and the affected UI/settings behavior depend on closing them.
