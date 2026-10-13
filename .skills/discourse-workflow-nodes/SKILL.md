---
name: discourse-workflow-nodes
description: Use when creating, changing, or reviewing Discourse Workflows nodes (triggers, actions, conditions) in plugins/discourse-workflows or plugins/*/lib/discourse_workflows, including their output schemas and specs
---

# Discourse Workflow Nodes

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

## Output conventions

- URLs are absolute (`Discourse.base_url + ...`, `full_url`). Keep existing relative keys such as `post_url`.
- Actions that may no-op output `changed` (boolean), computed by comparing state before and after (see badge, group, post_like).
- Actions that mutate a topic also return `topic`.
- Cap user lists with a named constant (e.g. `PostEventScoping::MAX_GOING_USERNAMES`).

## Output contracts

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
