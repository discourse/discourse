# Agent-owned AI conversations

AI conversation identity and model selection are independent:

- The selected **agent user** is the private-message recipient and the author of every newly created discussion response.
- The selected **LLM model** performs generation and is recorded as response provenance. Selecting another model does not add or replace a conversation participant.
- LLM records created after this change do not create, activate, deactivate, or delete users.

This applies to dedicated AI conversations, the standard and docked composers, public-topic mentions, chat, streaming, retry, Discover follow-ups, and posting automations.

## Stored routing data

Topic defaults use editable topic custom fields:

| Field | Meaning |
| --- | --- |
| `ai_agent_id` | Agent used when a turn does not explicitly address another agent |
| `ai_llm_model_id` | Model used when a turn does not carry another permitted model selection |

New reply jobs capture `agent_id`, `llm_model_id`, `authorization_user_id`, and the agent speaker ID before execution. Changing an agent or topic default after a job is queued does not alter that job's model. Execution revalidates the captured records and permissions. If the agent becomes unavailable after admission, a still-verifiable captured agent speaker may publish the visible routing failure. Post failures otherwise use the system user without AI provenance; a captured legacy model user never authors a new failure.

Post responses retain these custom fields:

- `ai_agent_id`
- `ai_llm_model_id`
- `ai_llm_name` (display-name snapshot)
- `ai_agent_authorization_user_id`

Chat responses store equivalent message custom fields. The display-name snapshot is intentional: model renames and deletion must not rewrite historical attribution. Agent-owned posts replace the technical bot username with the bold per-response agent name followed by the model snapshot. The current topic default is never used as historical authorship evidence. Read-only post attribution is registered for anonymous readers as well as members. Chat renders the model name directly. Neither uses an explanatory prefix. Legacy model-authored posts retain their original author identity. Safe schedule-time and execution-time chat routing failures are posted without model provenance, so they are not presented as completed generations.

## Resolution rules

1. An explicit agent wins; otherwise the topic agent or the General agent compatibility fallback is used.
2. The agent must be enabled, accessible to the initiating member, allowed in the discussion modality, and have an active dedicated user.
3. A forced-default agent always uses its configured model. An incompatible explicit model is rejected. Switching to a forced agent replaces the topic's inherited model default.
4. Other agents use an explicit model, then the topic model, then the agent default, then the site default.
5. Member-selected models must be present in `ai_bot_enabled_llms`. Agent and site defaults may be used without being member-selectable. A persisted topic model that still matches the current agent or site default retains that configured-default eligibility. A legacy model username supplied by a new request is treated as a member model selection; stored topic/post provenance remains available for authorized legacy continuation.
6. New discussion responses are always authored by the resolved agent user.
7. A failed retry leaves the existing answer intact. When the authorization and agent remain valid, the failure is posted separately by that agent.

Posting automations retain their existing trusted configuration boundary. They resolve the configured enabled agent directly and use the attributed user only for generation provenance and audit logging; they do not silently honor a caller-provided speaker override.

## Agent user provisioning

An enabled agent needs a dedicated user when it supports bot users and any posting modality is active, including `allow_personal_messages`. Admin create/update/import paths provision the user idempotently. The `603_ai_agents.rb` seed fixture also provisions missing users during setup and upgrades.

Provisioning is guarded by a row lock and allocates a distinct negative user ID. If a referenced agent user was deleted, provisioning repairs the association with a new user. Disabled agents are provisioned when they are enabled with a posting modality.

LLM `user_id` remains in the schema only to read historical installations. Normal model saves cannot add a new user association. Existing associations remain readable so old posts, private messages, flair, retry context, and shared transcripts continue to work. Clearing an old association or deleting its model records `discourse_ai_historical_user` on the retained user so later fixture runs do not remove its historical AI identity or flair.

## Client and API changes

The current-user payload separates agents from models:

- `ai_enabled_agents` contains agent IDs, users, modality flags, and agent defaults.
- `ai_available_llm_models` contains selectable model IDs and display metadata.
- `ai_enabled_chat_bots` is retained temporarily as an agent-only compatibility payload. New code must not use it to discover models.

New conversation requests accept:

```text
target_username=<agent username>
ai_agent_id=<agent ID>
ai_llm_model_id=<model ID>
```

Homepage and standard-composer selections submit `ai_agent_id` and `ai_llm_model_id` as per-turn fields; the server validates them and captures the execution snapshot. Explicit selector values update the topic defaults under a topic lock. A textual agent mention can route one turn without replacing existing conversation defaults. For new topics, the composer also includes the matching topic custom fields. The docked conversation composer intentionally omits agent/model controls and submits the topic's stored defaults.

The old `GET /discourse-ai/ai-bot/bot-username` model-to-recipient endpoint returns HTTP 410 Gone. Integrations must select an agent recipient and submit a model ID independently.

Browser model preference now uses `ai_llm_selector_model_id`. On first use, a stored `ai_llm_selector_id` legacy model-user ID is translated through `legacy_user_id` metadata when that historical association still exists. A forced agent's effective model does not replace this preference, and switching back to a non-forced agent restores it. An unavailable explicit topic or draft model ID is preserved for visible server rejection instead of being silently replaced with the first picker option. When no models are exposed in the member picker, the conversation UI can still submit an agent that has a configured agent or site default.

## Compatibility and rollout

No destructive migration removes historical model users or rewrites historical post authors. During rollout:

1. Deploy the code and run normal plugin seed fixtures. Confirm every enabled posting agent has a user.
2. Confirm newly created and updated LLMs keep `user_id` empty, including models added to `ai_bot_enabled_llms`.
3. Exercise a new General-agent PM, a PM-only agent, a forced-default agent, and a two-model switch in one existing PM.
4. Confirm the PM participant remains the agent while each response displays its actual model.
5. Verify a legacy model-user PM can continue through an accessible agent, while a new direct PM to that retired model user is rejected.
6. Monitor `Unable to schedule AI reply`, `Unable to create AI reply`, and invalid stream-resume warnings for stale records or permissions.

Historical LLM users can be cleaned up only in a later, separately audited migration after confirming they no longer own posts or participate in PMs. This change intentionally preserves them.
