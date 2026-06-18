# Workflow AI authoring use cases

Purpose: maintain a durable set of prompts for evaluating the Workflow AI authoring loop as schemas, tools, and prompting change.

## How to run a dev eval

Use the synchronous dev runner so the latest local code and tools are used:

```bash
bin/rails runner /tmp/workflow_ai_dev_run.rb '<prompt>' 'AI dev eval <id>' > /tmp/workflow_ai_<id>.json
```

For each run, record:

- Session/workflow IDs and status
- Tool calls used
- Proposal shape
- Whether Code nodes were avoided when declarative nodes are sufficient
- Whether `workflow_validate_patch` was used and final `expression_errors` is empty
- Token/time totals
- Any optimization applied

## Core regression prompts

| ID | Prompt | Expected shape | Key checks |
| --- | --- | --- | --- |
| `tl1-cake-chat` | `if a tl1 posts a post with the word cake make a post in the general chat channel linking to it` | `trigger:post_created -> condition:filter -> action:send_chat_message` | Uses `$json.user.trust_level` (trust level lives on the user object, not the post), `$json.post.raw`, `$json.post.post_url`; no Code node; chat template starts with `=`. |
| `support-tag-reply` | `when a new topic is created in Support, tag it needs-review and reply with Thanks for contacting support. Our team will review this soon.` | `trigger:topic_created -> action:topic_tags -> action:post (create)` | Resolves category/tag; after `action:topic_tags`, downstream reply uses `$json.topic_id`; no Code node. |
| `closed-support-wait-archive-chat` | `30 days after a topic in Support is closed, archive it and post a message in General chat linking to the topic` | `trigger:topic_closed -> flow:wait -> action:topic (archive) -> action:send_chat_message` | Uses `flow:wait`; no unnecessary forum search/read; topic link template starts with `=`. |
| `manual-maintenance-chat` | `create a manual workflow that sends a message to General chat saying Maintenance window is starting now` | `trigger:manual -> action:send_chat_message` | Static message does not need expression syntax; validates without expression errors. |
| `closed-general-tl1-chat` | `when a topic by a tl1 or lower is closed in the general category message the general channel with a link to the post` | `trigger:topic_closed -> action:topic (get) -> action:group (check_membership) -> condition:if -> action:send_chat_message` | Uses `action:topic` get to hydrate first-post fields (the topic payload has no `trust_level`). Resolves the `trust_level_2` automatic group and uses `action:group` with `operation: check_membership`, resolved `group_id`, and `username: ={{ $json.post.username }}`, then continues on the condition false branch (`group_membership.in_group == false`) for TL1-or-lower because `trust_level_N` is cumulative for TL >= N. Uses `$json.post.post_url`; no Code node; no clarification needed. |
| `friend-group-post-dm-admin` | `when anyone in the friend group posts send admin a dm with a link to the post` | `trigger:post_created -> action:group (check_membership) -> condition:if -> action:send_personal_message` | Resolves the `friend` group and `admin` user; sets resolved `group_id`, uses `$json.post.username` for membership, branches on `$json.group_membership.in_group`, and uses `$json.post.post_url` in a leading-`=` personal message body; no Code node. |

## Additional prompts to rotate into evals

| ID | Prompt | Expected shape | Key checks |
| --- | --- | --- | --- |
| `post-staff-exclusion` | `when a non-staff user posts in General and the post contains urgent, send a message to General chat with a link to the post` | `trigger:post_created -> condition:filter -> action:send_chat_message` | Uses boolean filter on `$json.post.staff` plus string contains on `$json.post.raw`; no Code node. |
| `topic-created-category-chat` | `when a new topic is created in Support by a TL0 user, message General chat with the topic title and post link` | `trigger:topic_created -> condition:filter -> action:send_chat_message` | Uses `$json.post.trust_level == 0`, `$json.topic.title`, `$json.post.post_url`. |
| `closed-topic-no-author-filter` | `when any topic in General is closed, message General chat with a link to the topic` | `trigger:topic_closed -> action:send_chat_message` or `trigger:topic_closed -> action:topic (get) -> action:send_chat_message` | If only topic link is needed, no author lookup is required; if post link is requested, use `action:topic` get. |
| `wait-chat-reminder` | `when a topic in Support is closed, wait 7 days and message General chat with the topic title` | `trigger:topic_closed -> flow:wait -> action:send_chat_message` | Wait parameters are `wait_amount: 7`, `wait_unit: days`; dynamic chat template starts with `=`. |
| `tag-only` | `when a new topic is created in Support, add the needs-review tag` | `trigger:topic_created -> action:topic_tags` | Resolves category/tag; no reply; no Code node. |
| `reply-only` | `when a new topic is created in Support, reply Thanks, we will review this shortly.` | `trigger:topic_created -> action:post (create)` | Uses `$json.topic.id`; no unnecessary tag lookup. |
| `post-created-category-filter` | `when a post is created in Support by a TL1 user, message General chat with the post link` | `trigger:post_created -> condition:filter -> action:send_chat_message` | Trigger category scoping or category filter is correct; uses `$json.post.trust_level`. |
| `archive-closed-topic` | `when a topic in Support is closed, wait 30 days and archive it` | `trigger:topic_closed -> flow:wait -> action:topic (archive)` | Uses archive operation, no chat lookup. |
| `manual-topic-create` | `create a manual workflow that creates a topic in General titled Maintenance update with body Maintenance is complete.` | `trigger:manual -> action:topic (create)` | Resolves category; create operation includes title/raw/category; no Code node. |
| `manual-log` | `create a manual workflow that writes a log entry saying Manual workflow ran` | `trigger:manual -> action:log` | No external discovery needed; no Code node. |
| `topic-admin-button-chat` | `add a topic admin button workflow that sends the current topic link to General chat` | `trigger:topic_admin_button -> action:send_chat_message` | Uses topic-only schema; dynamic template starts with `=`. |
| `tag-changed-chat` | `when a topic in Support gets the needs-review tag, message General chat with the topic title` | `trigger:topic_tag_changed -> condition:filter? -> action:send_chat_message` | Uses tag-changed schema for `added_tags`/`new_tags` if available; should query catalog first. |
| `category-changed-chat` | `when a topic is moved into Support, message General chat with a link to the topic` | `trigger:topic_category_changed -> action:send_chat_message` | Should query catalog for old/new category fields before drafting. |
| `badge-grant` | `when a TL1 user posts in General with the word helpful, grant them the Basic badge` | `trigger:post_created -> condition:filter -> action:badge` | Uses declarative filter; resolves badge; no Code node. |
| `group-add` | `when a TL1 user creates a topic in Support, add them to the helpers group` | `trigger:topic_created -> condition:filter -> action:group` | Uses `$json.post.username`; resolves group; no Code node. |
| `http-request-warning` | `when a new topic is created in Support, send the topic title to https://example.com/webhook` | `trigger:topic_created -> action:http_request` | Includes external HTTP risk; validates URL/method/body; no Code unless necessary. |

## Known edge cases to keep testing

- Topic-only triggers that need author/post fields should use `action:topic` get before filtering or messaging.
- Generic prompts like "when someone posts" should use `trigger:post_created` for all regular posts; do not ask whether to include replies unless the prompt explicitly narrows the scope.
- Actions that replace item JSON require downstream nodes to use the action output schema, not the original trigger schema.
- Dynamic strings containing `{{ }}` must start with `=`.
- Simple trust/text/category/staff checks should use `condition:filter`, not Code nodes. `condition:if` is for separate true/false branches.
- Trust level is only exposed as `$json.user.trust_level` on triggers with a user object (e.g. `trigger:post_created`); the post/topic payloads have no `trust_level`. When a trust-level check is needed but no `trust_level` field is in scope (topic-only triggers), resolve the cumulative `trust_level_N` automatic group and use `action:group` with `operation: check_membership` plus resolved `group_id` -- do not ask for clarification or add a Code node.
- Condition builder entries must use `leftValue` and `rightValue`; `left`/`right` will not execute correctly.
- Connections leaving `condition:filter` or `condition:if` should use `connection_type: "true"` for the passing branch, not `main`.
- Group membership checks should use `action:group` with `operation: check_membership` and the resolved `group_id` instead of Code nodes. Branch with `condition:if` on `$json.group_membership.in_group` when different member and non-member paths are needed.
- DM/personal-message notifications should use `action:send_personal_message` instead of chat or topic reply nodes.
- Forum `search`/`read` should not be used for node/schema discovery; use `workflow_node_catalog` and `workflow_validate_patch`.
