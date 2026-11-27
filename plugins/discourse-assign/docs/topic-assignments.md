# Topic assignment behavior and constraints

Investigation baseline: `b7d63facd95`, 4 November 2026. This describes current behavior and the constraints relevant to enabling multiple topic assignees behind a site setting. It does not implement or settle the feature design.

The subsequent [multiple topic assignments implementation plan](multiple-topic-assignments-plan.md) describes the proposed changes and rollout.

A topic currently has at most one direct assignment, to either a user or a group. Each post can separately have one assignment. Post assignments belong to the same topic for filtering and display, but do not create additional direct topic assignments. There is a hard-coded limit of five active assignments across the topic and its posts.

## Persistence

The source of truth is `assignments`, defined in the repository schema at [`db/structure.sql`](../../../db/structure.sql) and represented by [`Assignment`](../app/models/assignment.rb).

| Column | Type and constraints | Meaning |
| --- | --- | --- |
| `id` | bigint, primary key | Assignment identity, also referenced in notification JSON |
| `topic_id` | integer, not null | Owning topic for both topic and post assignments |
| `target_id`, `target_type` | integer and string, not null | Polymorphic target: `Topic` or `Post` |
| `assigned_to_id`, `assigned_to_type` | integer and string, not null | Polymorphic assignee: `User` or `Group` |
| `assigned_by_user_id` | integer, not null | User who created the assignment |
| `active` | boolean, default true, nullable in schema | Whether the assignment is active |
| `note` | nullable string | Note belonging to this assignment |
| `status` | nullable text | Status belonging to this assignment |
| `created_at`, `updated_at` | timestamps, not null | Assignment creation and update times |

For a topic assignment, `target_type = 'Topic'` and `target_id = topic_id`. For a post assignment, `target_type = 'Post'`, `target_id = posts.id`, and `topic_id = posts.topic_id`.

The current indexes are:

- Unique `(target_id, target_type)`: the database enforces one row per target, including inactive rows.
- Unique `(assigned_to_id, assigned_to_type, target_id, target_type)`, named `unique_target_and_assigned`: prevents duplicate assignment of the same target to the same user or group. The stronger target-only index currently makes this redundant.
- Nonunique indexes on `topic_id`, `active`, and `(assigned_to_id, assigned_to_type)`.

There are no foreign keys on these assignment relationships in the checked-in schema. Both [`TopicExtension`](../lib/discourse_assign/topic_extension.rb) and [`PostExtension`](../lib/discourse_assign/post_extension.rb) declare `has_one :assignment, as: :target, dependent: :destroy`. The topic association is specifically the direct assignment, not all rows with its `topic_id`.

`silenced_assignments` stores `assignment_id` as a unique, non-null bigint plus its own ID and timestamps. It suppresses assignment notifications for rows created with `should_notify: false`. Assignment notifications live in core `notifications`; `data.assignment_id` identifies their assignment.

The schema evolved from a unique `topic_id` in the [original table migration](../db/migrate/20210627100932_create_assignments.rb), through a polymorphic assignee, to [polymorphic targets and target uniqueness](../db/migrate/20211006223156_add_target_to_assignments.rb). The unique topic index was subsequently removed, and a nonunique topic index was added. Legacy topic custom fields are not the current assignment source of truth.

## Assigning and reassigning

The frontend uses [`TaskActions`](../assets/javascripts/discourse/services/task-actions.js). The topic controls open [`EditTopicAssignments`](../assets/javascripts/discourse/components/modal/edit-topic-assignments.gjs), while other entry points use the single-target assign modal. The edit modal obtains one topic entry plus existing post entries from the [topic model extensions](../assets/javascripts/discourse/models/topic.js).

The “Assignment” dropdown selects the topic or an already assigned post. It does not select multiple assignees. [`Assignment`](../assets/javascripts/discourse/components/assignment.gjs) configures the chooser with `maximum=1`, reads only the first selected item, and stores either `username` or `group_name`. Suggestions and search are target-aware.

Saving sends `PUT /assign/assign` with `target_type`, `target_id`, one `username` or `group_name`, optional `note` and `status`, and optionally `should_notify`. The standard frontend payload does not send `should_notify`. [`AssignController`](../app/controllers/discourse_assign/assign_controller.rb) resolves one assignee and invokes [`Assigner#assign`](../lib/assigner.rb). If both assignee parameters are supplied, the resolver chooses the username. Successful requests return confirmation JSON rather than an updated assignment representation.

`Assigner#assign`:

1. Checks the actor's assignment permission, assignee eligibility, target visibility, note length, duplicate assignment, and assignment limits. With `invite_on_assign`, it attempts PM invitations before the later eligibility checks.
2. Updates the existing row in place when the assignee is unchanged and details change. An identical active assignment normally returns an already-assigned failure.
3. Otherwise queues removal of the old assignment's notifications, destroys the target's existing row, and creates a new assignment row. Assigning Bob to a topic assigned to Alice therefore replaces Alice, including when the old row was inactive.
4. Publishes a first-post revision/reload and assignment MessageBus event, queues notifications, applies the directly assigned user's tracking/watching preference, and sends email when configured and the topic is not muted for that user.
5. Creates a moderator action post, sends an assignment webhook when configured, and triggers the `:assigned` event. Details updates follow a shorter path and do not run all of these creation side effects.

The current replacement path has no encompassing transaction or topic lock around the destroy/create sequence and limit check. New additive operations would need explicit concurrency handling; merely removing uniqueness would also remove a current database backstop.

[`TopicAssigner`](../lib/topic_assigner.rb) is a deprecated compatibility wrapper. Current business logic is in `Assigner`.

## Unassigning and lifecycle

`PUT /assign/unassign` identifies a target, not an assignment or assignee. `Assigner#unassign` destroys that target's single row, queues notification removal, publishes updates, optionally adds an action post, and emits webhook/event side effects. It leaves assignments on other targets in the topic intact. Unassigning does not restore the user's previous topic notification level.

Lifecycle listeners in [`plugin.rb`](../plugin.rb) also change assignments:

- `unassign_on_close` deactivates the direct topic assignment and post assignments rather than destroying them. `reassign_on_open` reactivates retained rows.
- Deleting an assigned post deactivates its assignment. Recovery can reactivate it when `reassign_on_open` is enabled.
- Group PM archive/inbox behavior can deactivate/reactivate topic-owned assignments with `unassign_on_group_archive`; parts of the path assume a single direct assignment exists.
- Moving a post updates its assignment's owning topic. When it becomes the first post, the listener converts its target to the destination topic.
- Adding/removing group members creates/removes their notifications for group assignments. Destroying a group removes active group assignments.

Inactive rows retain their note, status, assignee, and unique target slot. They support reactivation, not a complete assignment history. Reassignment and ordinary unassignment delete rows; moderator action posts retain the visible activity trail.

## Display and assigned lists

| Surface | Current implementation and data |
| --- | --- |
| First-post assignment text, corresponding to screenshot 1 | [`PostAssignmentsDisplay`](../assets/javascripts/discourse/components/post-assignments-display.gjs) renders [`AssignedToFirstPost`](../assets/javascripts/discourse/components/assigned-to-first-post.gjs), using one direct user/group plus indirect post assignments. The separate action row comes from the moderator post created by `Assigner`. |
| Assignment modal, corresponding to screenshot 2 | The edit modal selects one target and edits that target's single assignee, note, and optional status. Saving edited targets performs sequential requests, not an atomic topic-wide update. |
| User menu, corresponding to screenshot 3 | [`assign-user-menu`](../assets/javascripts/discourse/initializers/assign-user-menu.js) registers an assigned-notification tab for globally assignment-enabled users. [`assigns-list`](../assets/javascripts/discourse/components/user-menu/assigns-list.js) loads core notifications of type `assigned`, ordered unread first, then topic bump time and notification creation time. It is a notification list, not a direct query of assignment rows. |
| User activity Assigned tab, corresponding to screenshot 4 | [`user-activity/assigned`](../assets/javascripts/discourse/routes/user-activity/assigned.js) requests `/topics/messages-assigned/:username`. `TopicQuery#list_messages_assigned` includes visible topics/PMs with active assignments to the user or their groups, including post assignments. `direct=true` excludes group assignments; it does not mean topic targets only. |

Topic serializers expose singular `assigned_to_user` or `assigned_to_group`, `assignment_note`, and optional `assignment_status`. Post assignments are exposed as `indirectly_assigned_to`, a map keyed by post ID containing one assignee per post. Topic lists, search results, bookmarks, flagged topics, suggested topics, and the admin assigned endpoint also contain singular assumptions.

Preloaders use `find`, `index_by`, or maps to choose one direct assignment. Additional database rows alone would therefore be omitted or overwritten in several read paths. The frontend topic assignment uses a synthetic ID of `0`, and post assignment entries use post numbers; these are not database assignment IDs.

MessageBus publishes `/staff/topic-assignment` with one assigned entity, target information, note, and status. Its frontend consumer overwrites the target's scalar fields. An unassign event identifies the topic/post and assignee type, but carries neither assignment ID nor removed assignee ID. It cannot currently distinguish removing one of several direct assignees.

[`CreateNotification`](../lib/discourse_assign/create_notification.rb) creates notifications per assignment and recipient; a group assignment fans out to group members. Self-assignment creates a read notification. Unassign jobs remove notifications by assignment ID. This identity already supports separate assignment rows, but overlapping direct/group/post assignments can produce multiple notifications for the same topic and recipient. The activity query uses a topic-ID subquery and naturally returns a topic once.

## Limits and permissions

- `Assigner::ASSIGNMENTS_PER_TOPIC_LIMIT = 5` counts active rows across topic and post targets. Replacing an active target assignment is allowed at the limit. This is not a configurable per-topic setting.
- `max_assigned_topics` defaults to 10. The enforcement query counts active direct topic-target assignments for the recipient ID; it does not count post assignments. Groups and self-assignment bypass this check. The query currently omits `assigned_to_type`, so a group ID matching a user ID can affect that user's count.
- Suggestion eligibility uses a different count over assignment rows, including inactive and post rows. Assignment counts, unique topic counts, and notification counts are already different concepts.
- Actor permissions come from administrators, configured global assignment groups, and category-scoped additional groups. Assignees are restricted through `AssignmentPermissions`; assignable groups also use group assignability rules. Users must be able to see the target; every group member must be able to see it. PM participation can be added by `invite_on_assign`.
- `assigns_public` controls public assignment display and whether tracking posts are small actions or whispers. Serializers and MessageBus delivery apply their respective assignment permission rules. The user activity and group assigned endpoints require global assignment permission.
- `enable_assign_status` enables status validation against `assign_statuses` and default status selection. Note/status belong to an assignment row, not the topic globally. Notes are limited to `max_post_length` by the assigner.
- There is currently no setting for multiple direct topic assignees.

## Dependencies for a later design

The existing row structure can represent one row per assignee without introducing a separate assignee join table. Enabling that requires changing target uniqueness and replacing singular associations and contracts. Keeping post assignments singular would require preserving that invariant separately.

The implementation surface includes assignment/unassignment APIs, `Assigner`, associations, serializers/preloaders, topic controls and assignment displays, MessageBus events, notifications, list actions, counts/reminders, lifecycle listeners, bulk actions, mention-based autoassignment, webhooks, and integrations. Search and some assigned lists already use topic-ID subqueries; join-based filters and counts need checking for duplicate rows and pagination effects.

Consumers outside the main UI include assignment workflow nodes under `lib/discourse_workflows/nodes`, the `:assign_topic`/`:unassign_topic` events, solved-status handlers, random assignment automation, [Boards topic mutation](../../boards/app/services/boards/topic_mutator.rb) and [card topic serialization](../../boards/app/serializers/boards/card_topic_serializer.rb), and the [AI assignment tool](../../discourse-ai/lib/agents/tools/assign.rb). These currently assume or invoke single-target assignment behavior.

## Agreed feature behavior

The new mode will allow multiple users and at most one group alongside them on a topic. The modal will edit the full assignee list, and the topic display will allow removing an individual assignment. Each assignment will retain its own note and status.

Existing single-assignee callers, including API clients, workflows, Boards, and autoassignment, will retain replacement behavior. Adding an assignee will require a new explicit operation.

Direct and group assignments will retain separate records when their recipients overlap. Assignment notifications will notify a user only when they newly become responsible; exact handling of notification retention and later changes remains to be designed.

Individual post assignments will remain limited to one user or group. Only direct topic assignments gain multiple assignees.

The existing hard-coded five-assignment limit will be replaced by a hidden setting defaulting to 20 active assignments across the topic and its posts. This counts assignment records, so an assigned group occupies one slot.

The provisional modal direction is a row per assignee with separate note and status controls. This remains pending design.

Behavior when the multi-assignment setting is disabled after multiple assignments exist is explicitly deferred.

## Remaining design decisions

Decisions needed before implementation:

1. The explicit API contracts for adding, editing, removing one assignment, and replacing the full set, including concurrency and atomic modal saves.
2. The final modal and topic-display design, including individual removal and each assignee's note/status controls.
3. Notification retention when direct and group recipients overlap, workload counts, and topic-list deduplication.
4. How the setting behaves when disabled after multiple assignments exist, preserving data and defining what legacy readers and writers see. This decision is deferred.
5. How to deploy schema and contract changes while old processes may still read and write singular assignments.

Existing regression coverage is concentrated in `spec/lib/assigner_spec.rb`, `spec/models/assignment_spec.rb`, `spec/requests/assign_controller_spec.rb`, serializer/topic-query/search specs, and system specs for topic/post assignment and the user menu. These establish current replacement, limit, notification, permission, and lifecycle behavior for compatibility testing.
