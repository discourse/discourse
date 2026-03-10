# AI Tool Approval Queue Plan

## Context

We added 13 moderation tools (CloseTopic, UnlistTopic, LockPost, DeleteTopic, EditPost, EditTags, EditCategory, SetTopicTimer, SetSlowMode, MovePosts, GrantBadge, Assign, MarkAsSolved) that AI agents execute immediately. Most deployments want a human-in-the-loop: actions go to a queue, a moderator approves or rejects, and only then do they execute.

Primary use case is **Automations**, not AI Bot conversations. The LLM receives `{status: "pending_approval"}` so it can continue processing remaining tool calls.

## Approach: Reviewable System + Per-Agent Boolean

Use Discourse's existing `Reviewable` STI system with a new `ReviewableAiToolAction` subclass. This gives us permissions, audit trail, optimistic locking, notifications, and the review queue UI for free. The "approve = execute deferred action" pattern already exists in `ReviewableQueuedPost`.

A new `AiToolAction` model serves as the Reviewable target record, giving us proper FK relationships and compatibility with the standard Reviewable lookup/bulk machinery.

Approval is controlled by a single `require_approval` boolean on `ai_agents` (MVP). Per-tool granularity is deferred to a future iteration.

---

## 1. Database Migrations

**File: `db/migrate/XXXXXX_create_ai_tool_actions.rb`** (NEW)

```ruby
create_table :ai_tool_actions do |t|
  t.string :tool_name, null: false
  t.jsonb :tool_parameters, default: {}, null: false
  t.references :ai_agent, null: false
  t.integer :bot_user_id, null: false
  t.integer :post_id
  t.timestamps
end
```

**File: `db/migrate/XXXXXX_add_require_approval_to_ai_agents.rb`** (NEW)

```ruby
add_column :ai_agents, :require_approval, :boolean, default: false, null: false
```

Default `false` so existing agents are unaffected.

---

## 2. Tool Base Class: `requires_approval?` Marker

**File: `lib/agents/tools/tool.rb`** (inside `class << self`)

Add class method:
```ruby
def self.requires_approval?
  false
end
```

Override to `true` in all 13 moderation tool classes. This is a static marker indicating the tool *can* require approval — runtime decision uses the agent's `require_approval` boolean.

Tools: `close_topic`, `unlist_topic`, `lock_post`, `delete_topic`, `edit_post`, `edit_tags`, `edit_category`, `set_topic_timer`, `set_slow_mode`, `move_posts`, `grant_badge`, `assign`, `mark_as_solved`.

---

## 3. AiToolAction Model

**File: `app/models/ai_tool_action.rb`** (NEW)

Lightweight record that serves as the `target` for `ReviewableAiToolAction`. Stores the deferred tool invocation data.

```ruby
class AiToolAction < ActiveRecord::Base
  belongs_to :ai_agent
  validates :tool_name, presence: true
end
```

This solves the `target: nil` problem from v1 of the plan — we get proper FK, standard `Reviewable.find_by(target:)` lookups, and compatibility with bulk machinery.

---

## 4. ReviewableAiToolAction Model

**File: `app/models/reviewable_ai_tool_action.rb`** (NEW)

Subclass of `Reviewable` with `target_type: "AiToolAction"`.

**Payload schema** (stored in `payload` JSON column):
```json
{
  "agent_name": "Moderator Bot",
  "reason": "Off-topic",
  "llm_model_id": 5
}
```

Lightweight payload — the heavy data (tool_name, tool_parameters, ai_agent_id, bot_user_id, post_id) lives on the `AiToolAction` target record.

**Actions:**
- `approve` — Reinstantiate tool from `AiToolAction` data, call `tool.invoke`, transition to `:approved`. On stale target (e.g. topic deleted), show warning to admin with payload data for manual action.
- `reject` — Transition to `:rejected`, no side effects

**Key implementation details:**
- `build_actions(actions, guardian, args)` — approve + reject bundles (following `ReviewableAiPost` pattern)
- `perform_approve(performed_by, args)` — find tool class by matching `tool_name` against `Agent.all_available_tools`, instantiate with saved params, invoke. Pass `llm: nil` since no moderation tool uses LLM during `invoke`. On failure, return `create_result(:failed)` with error message so admin sees what happened.
- `perform_reject(performed_by, args)` — `create_result(:success, :rejected)`
- Set `reviewable_by_moderator: true`, `force_review: true`, `potential_spam: false`

---

## 5. Interception in bot.rb

**File: `lib/agents/bot.rb`** (modify `invoke_tool`)

```ruby
def invoke_tool(tool, context, &update_blk)
  if tool_requires_approval?(tool)
    return enqueue_tool_for_approval(tool, &update_blk)
  end
  # ... existing logic unchanged ...
end
```

**New private methods:**

`tool_requires_approval?(tool)` — checks `tool.class.requires_approval?` AND the agent's `require_approval` boolean. Both must be true. Lookup via `AiAgent.all_agent_records` cache (already used elsewhere).

`enqueue_tool_for_approval(tool, &update_blk)` — creates `AiToolAction` record, then creates `ReviewableAiToolAction` via `needs_review!` with that record as target. Must also call `add_score(Discourse.system_user, ReviewableScore.types[:needs_approval], force_review: true)` so the reviewable appears in the queue. Shows "pending approval" placeholder via `update_blk`. Returns `{status: "pending_approval", message: "This action requires moderator approval before it can be executed."}` to the LLM so it can continue with other tool calls.

---

## 6. Serializer

**File: `app/serializers/reviewable_ai_tool_action_serializer.rb`** (NEW)

```ruby
class ReviewableAiToolActionSerializer < ReviewableSerializer
  payload_attributes :agent_name, :reason, :llm_model_id
end
```

The target `AiToolAction` attributes (tool_name, tool_parameters, etc.) are serialized through the standard `target` relationship.

---

## 7. Plugin Registration

**File: `plugin.rb`** (after existing reviewable registrations)

```ruby
register_reviewable_type ReviewableAiToolAction
```

---

## 8. Frontend Component

**File: `assets/javascripts/discourse/components/reviewable/ai-tool-action.gjs`** (NEW)

Displays:
- Agent name + avatar (bot user)
- Tool action name (localized)
- Tool parameters formatted for readability (target topic/post link, reason, key params)
- Link to triggering post (from `AiToolAction.post_id`)
- Standard approve/reject buttons (Reviewable framework handles these)

---

## 9. Agent Admin UI Updates

**Files to modify:**
- `admin/assets/javascripts/discourse/components/ai-agent-editor.gjs` — Add "Require Approval" toggle checkbox
- `app/serializers/localized_ai_agent_serializer.rb` — Add `require_approval`
- `app/controllers/discourse_ai/admin/ai_agents_controller.rb` — Permit `require_approval`

---

## 10. AiAgent Model Update

**File: `app/models/ai_agent.rb`**

Add `require_approval` to the `attributes` array in `class_instance` so it's available on the agent class:

```ruby
attributes = %i[
  id
  ...
  require_approval
]
```

---

## 11. i18n

**Server** (`config/locales/server.en.yml`):
- `discourse_ai.ai_bot.tool_pending_approval` — message returned to LLM
- `discourse_ai.reviewable_ai_tool_action.title` / `description`
- `discourse_ai.reviewable_ai_tool_action.actions.approve` / `reject`

**Client** (`config/locales/client.en.yml`):
- "Require Approval" toggle label + description for agent editor
- Reviewable component display strings

---

## 12. Implementation Sequence

1. Migrations: `ai_tool_actions` table + `require_approval` on `ai_agents`
2. `AiToolAction` model
3. Tool base class: add `requires_approval?`, override in 13 moderation tools
4. `AiAgent` model: add `require_approval` to `class_instance` attributes
5. `ReviewableAiToolAction` model + serializer
6. Register reviewable type in `plugin.rb`
7. Bot interception: modify `invoke_tool` in `bot.rb`
8. i18n strings
9. Frontend reviewable component
10. Agent admin UI toggle
11. Tests

---

## 13. Files Summary

| File | Change |
|------|--------|
| `db/migrate/XXXXXX_create_ai_tool_actions.rb` | **NEW** — migration |
| `db/migrate/XXXXXX_add_require_approval_to_ai_agents.rb` | **NEW** — migration |
| `app/models/ai_tool_action.rb` | **NEW** — target record for reviewable |
| `app/models/reviewable_ai_tool_action.rb` | **NEW** — Reviewable subclass |
| `app/serializers/reviewable_ai_tool_action_serializer.rb` | **NEW** |
| `lib/agents/tools/tool.rb` | Add `requires_approval?` class method |
| `lib/agents/tools/{13 tools}.rb` | Override `requires_approval?` → true |
| `lib/agents/bot.rb` | Gate `invoke_tool` with approval check |
| `app/models/ai_agent.rb` | Add `require_approval` to `class_instance` attributes |
| `assets/javascripts/discourse/components/reviewable/ai-tool-action.gjs` | **NEW** — review queue UI |
| `admin/assets/javascripts/discourse/components/ai-agent-editor.gjs` | Add approval toggle |
| `app/serializers/localized_ai_agent_serializer.rb` | Add `require_approval` |
| `app/controllers/discourse_ai/admin/ai_agents_controller.rb` | Permit `require_approval` |
| `plugin.rb` | Register ReviewableAiToolAction |
| `config/locales/server.en.yml` | i18n keys |
| `config/locales/client.en.yml` | i18n keys |

All paths relative to `plugins/discourse-ai/`.

---

## 14. Verification

1. **Unit tests**: ReviewableAiToolAction — approve executes tool, reject discards, handles missing target
2. **Integration test**: Bot with `require_approval: true` agent → tool returns pending → AiToolAction + reviewable created → approve → tool executes
3. **Regression**: `require_approval: false` agents still execute immediately, no reviewable created
4. **Stale target test**: Approve after target deleted → admin sees failure message with payload data
5. **Existing specs**: `bin/rspec plugins/discourse-ai/spec/lib/agents/tools/` — all pass unchanged
6. **Lint**: `bin/lint` on all changed files

---

## 15. Edge Cases

- **Stale target**: Topic/post deleted between queueing and approval → `tool.invoke` returns error → admin sees warning with full payload data so they can act manually
- **Agent deleted**: `perform_approve` can't find agent → `create_result(:failed)` with descriptive error
- **Duplicate actions**: Same tool on same target queued twice → each gets its own `AiToolAction` record and reviewable. Moderator handles independently
- **LLM continuation**: Bot gets `{status: "pending_approval"}` and continues with remaining tool calls. LLM adapts naturally — informs user, proceeds with non-blocked actions

---

## 16. Deferred (Future Iterations)

- **Per-tool granularity**: Replace `require_approval` boolean with JSONB `tool_approval_rules` for per-tool overrides
- **Bulk actions controller**: Dedicated endpoints for filtered bulk approve/reject if the built-in review queue bulk actions prove insufficient
- **Post-approval notifications**: After approval, post a follow-up message in the conversation thread
