---
name: discourse-workflow-nodes
description: Use when creating, changing, splitting, or reviewing Discourse Workflows nodes (triggers, actions, conditions, flow) in plugins/discourse-workflows or plugins/*/lib/discourse_workflows, including their settings, output schemas, events, and specs
---

# Discourse Workflow Nodes

Nodes are small bricks admins combine in the workflow editor. Each node does one thing, is findable by the name
of what it does, and has a trigger counterpart when it changes state.

## Granularity

1. **Resource nodes own lifecycle, reads, and field edits.** `create`, `get`, `list`, `edit`, `delete`,
   `recover`, and edits of a value or of a set edited as a whole (category, tags, trust level, custom fields,
   a tag group's tags) are operations on one node per noun: Topic, Post, User, Group, Data table…
2. **A change with a natural opposite gets one node per direction, as an action and as a trigger.**
   Close / Reopen topic, Pin / Unpin topic, Like / Unlike post, Add user to / Remove user from group,
   Grant / Revoke badge, Suspend / Unsuspend user, Set / Clear topic timer. Judge by the underlying event,
   not by today's trigger: `:topic_timer_changed` passes `created`, `updated`, `cancelled` or `completed`,
   so the timer gets split triggers and split actions.
3. **Triggers split per change, keeping the generic trigger hidden.** The generic `*_changed` trigger stays
   registered with `palette_visible: false` because it can match several changes in one node. Each change gets
   a palette trigger built from it, as `TopicStatusChanged::V1.description_for_change("closed")` does.
   Splitting a trigger never breaks saved workflows.
4. **Actions don't keep a hidden generic.** Picking the direction from data is an If node feeding two actions.
5. **Share code, not nodes.** Nodes that differ only by direction share a module (see `PostLifecycle`).
   Never add an intermediate base class: every `NodeType` subclass registers itself as a node.

## Naming

| | Identifier | Label | Example |
|---|---|---|---|
| Action | `action:<verb>_<noun>` | Imperative, sentence case | `action:close_topic`, "Close topic" |
| Trigger | `trigger:<noun>_<past participle>` | Noun + past participle | `trigger:topic_closed`, "Topic closed" |
| Resource node | `action:<noun>` | Noun | `action:topic`, "Topic" |

The palette search matches a node's label, its operation labels and its search terms
(`discourse_workflows.node_search_terms."<identifier>"` in `client.en.yml`, comma-separated). Add search terms
for words admins would type that aren't in the name, such as "hide" for unlisting a topic.

## Settings

- Option lists that come from site data or runtime registries (groups, badges, channels, reviewable types,
  site settings) use `type_options: { load_options_method: "…" }`, answered by `self.load_options_context`.
  Never compute them inside `properties`: a node's definition must not depend on the site or on which plugins
  are enabled.
- Static option lists stay inline in `options`.
- The AI author resolves loaded option values through `workflow_resolve_entity(kind: "node_option")`, which
  calls the node's `self.load_options_context` the way the editor does, so a new option list needs no
  AI-specific code. Loaders that need credentials return nothing there.

## Entities in output

Shape entities only with `DiscourseWorkflows::EntitySerializers` (`lib/discourse_workflows/entity_serializers.rb`), available in `NodeType` instance and class methods:

| Entity | Builder | Schema |
|---|---|---|
| User | `serialize_user(user, guardian:)` (nil for nil user) | `Schema::USER_SCHEMA` / `USER_PROPERTIES` / `Schema.nullable_user(description)` |
| Topic (triggers) | `serialize_topic_list_item(topic, scope:)` | `Schema::TOPIC_LIST_ITEM_SCHEMA` / `TOPIC_PROPERTIES` |
| Topic (actions) | `serialize_topic(topic, guardian:, custom_field_names:)` | `TOPIC_LIST_ITEM_SCHEMA` |
| Post | `serialize_post(post, guardian:, include_raw:, include_cooked:)` (nil for nil post) | `Schema::POST_SCHEMA` / `POST_PROPERTIES` |
| Reviewable | `serialize_reviewable(reviewable)` | `Schema::REVIEWABLE_EVENT_SCHEMA` |
| Assignee (user or group) | `serialize_assignee(assignee, guardian:)` | `Schema::ASSIGNEE_PROPERTIES` |
| Group (basic) | `serialize_basic_group(group)` | `BASIC_GROUP_PROPERTIES` |
| Any serializer | `serialize_record(record, SerializerClass, scope:)` | |

- Name every helper that shapes an entity for output `serialize_<entity>` (`serialize_badge`, `serialize_group`, `serialize_timer`, `serialize_assignee`, `serialize_channel`, `serialize_event`...), never `<entity>_data`; `node_entity_builders_spec` fails on `def <entity>_data`.
- Don't wrap a shared builder in a node-private helper; call it directly.
- `serialize_topic_list_item` (`DiscourseWorkflows::TopicListItemSerializer`) carries plugin-added list fields (assign `assigned_to_*`, solved `has_accepted_answer`, voting `can_vote`/`vote_count`...); `serialize_topic` (`DiscourseWorkflows::TopicSerializer`) adds posters, participants and custom fields. Both emit every `TOPIC_PROPERTIES` key.
- Outside a `NodeType`, call them on the module: `DiscourseWorkflows::EntitySerializers.serialize_user(...)`.
- Never use `BasicUserSerializer` or `TopicListItemSerializer` in node files; `node_entity_builders_spec` fails if you do.
- Groups: `BasicGroupSerializer` (`BASIC_GROUP_PROPERTIES`) or `WebHookGroupSerializer` (`GROUP_SCHEMA`).

## `user` vs `actor`

- `user` is the subject: the post/topic author, or the affected account.
- `actor` is whoever performed the action, built with `serialize_user` and declared with `Schema::ACTOR_SCHEMA` (nullable).
- Emit both, even when they are the same person (liker, voter, participant).
- Output never uses `acting_user`; events never use `actor:`.

## Events pass the acting user

Fire events with the actor as a trailing `acting_user:` kwarg:

```ruby
DiscourseEvent.trigger(:topic_status_updated, topic, status, enabled, acting_user: user)
```

Trigger nodes receive it as a trailing hash: `def initialize(topic, status, enabled, payload = {})` and read `payload[:acting_user]`. Specs that assert exact event params must include `{ acting_user: ... }`.

- Every state change an action makes fires a `DiscourseEvent`, so a trigger can mirror it. If core or the plugin doesn't fire one, add it.
- Fire it where the change happens, in the model method or service, not in the controller.
- Jobs and automatic changes pass `Discourse.system_user`. Expiry jobs fire the event too: a change that happens on a timer is still a change (`Jobs::ClearSlowMode`).
- When a record is saved from many places and its owner isn't who changed it, carry the user on the record rather than guessing in the trigger.
- When the change only happens in a controller, move it into a core service that fires the event after its transaction, only when something changed, and call that service from the controller and the action alike (`Topic::UpdateSlowMode`).
- When a model method wraps the change in a transaction that can still roll back, register the event with `DB.after_commit` after its success check, and only when the state really changed, so a failed or no-op call never fires it.
- Pass every positional argument, even when it's `nil`, so the trailing hash never binds to an optional positional.
- When an event gains `acting_user:`, every trigger listening to it must accept the trailing hash (`payload = {}`, or a `from_event` override that drops it). Otherwise building the trigger raises `ArgumentError`, which `EventListener` logs and swallows, so the trigger silently stops firing.
- Declare `actor` only once the event carries `acting_user:` (or the actor is known by construction). Never declare an `actor` that is always `null`: make the event carry the user first.

## Breaking output changes

Renaming or removing an output key, or changing its meaning, breaks saved workflows. Ship a new version instead; additive keys can go in the existing version.

- Freeze V1 and mark it, after `description(...)`: `deprecated(superseded_by: "2.0", changes: { "editor" => "actor" })`.
- The shared `node_descriptions.<identifier>` locale describes the latest version. If it no longer fits V1, add `description_key: "discourse_workflows.node_descriptions.<identifier>_v1"` to `deprecated(...)` with V1's text; V2 does not inherit it.
- `class V2 < V1` in `v2.rb`, calling `description(superclass.description.merge(version: "2.0", output_contracts: [{ schema: V2_OUTPUT_SCHEMA }]))`, then override `output` / `execute` or a private `serialize_*` helper.
- Core nodes self-register; plugin nodes need `register_discourse_workflows_node(...::V2)` next to V1.
- Services resolve the saved version with `NodeData.node_type(node)`, never a hard-coded `V1`.
- Deprecated versions keep running for saved workflows, are hidden from the palette and AI catalog, and show an editor notice with an Upgrade action. Remove them after a deprecation window.
- Spec both: `match_node_output_schema(Foo::V1)` pins the old keys, `match_node_output_schema(Foo::V2)` the new ones. `node_deprecation_spec` checks `superseded_by`.

## Output conventions

- URLs are absolute (`Discourse.base_url + ...`, `full_url`). Keep existing relative keys such as `post_url`.
- Actions that may no-op output `changed` (boolean), computed by comparing state before and after (see badge, group, post_like).
- Actions that mutate a topic also return `topic`.
- Cap user lists with a named constant (e.g. `PostEventScoping::MAX_GOING_USERNAMES`).

## Secrets

- Never put credential values in output. Password credential fields serialize as `Credential::REDACTED_VALUE`.
- `WebhookRequest` masks `FILTERED_HEADERS` (`authorization`, `cookie`, `proxy-authorization`) with `FILTERED_VALUE`; `AuthenticateNode` masks the matched `header_auth` header.
- http_request logs headers through `redact_headers`.

## Output contracts

Every node declares its output with `output_contracts` in `description`, or derives it from config by overriding `self.output_schemas` (see summarize, data_table, trigger:form, action:form). The editor fetches resolved schemas from the server (`POST /output-schemas`), so there is no JS counterpart.

`node_output_contracts_spec` has a `user_defined_output` opt-out list. A node belongs there only if the user writes its output shape (code, sql, set_fields, workflow_call, manual). If the shape can be derived from config, override `self.output_schemas` instead.

- Use `"type": [..., "null"]` for keys that are always emitted but may be nil.
- Use `"x-optional": true` for keys that are only emitted on some paths, such as DM-only `usernames`, or `tags` when the guardian can't see them. Optional objects may be `{}`.
- `schema_serializer_sync_spec` fails when a declared serializer key is never emitted.

## Specs

Every node spec asserts the real output against the declared contract:

```ruby
expect(output).to match_node_output_schema(DiscourseWorkflows::Nodes::Foo::V1, configuration: config)
```

The matcher is strict: every declared property is required unless `x-optional`, and types must match. Run plugin specs with `LOAD_PLUGINS=1 bin/rspec`.
