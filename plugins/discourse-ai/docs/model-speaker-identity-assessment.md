# AI model and speaker identity assessment

Status: proposal, not an implementation plan approved for execution.

## Findings

LLM configuration and conversation identity are coupled:

- `app/models/llm_model.rb`, `toggle_companion_user`: creates a negative-ID, active, approved, admin/moderator, TL4 user when `ai_bot_enabled` and the model is selected in `ai_bot_enabled_llms`. Merely configuring an arbitrary model does not necessarily create an account.
- `app/controllers/discourse_ai/admin/ai_llms_controller.rb` invokes this lifecycle on create/update. `lib/ai_bot/entry_point.rb` and `site_settings_extension.rb` synchronize it on relevant setting changes.
- `cleanup_companion_user` retains and deactivates users with posts (including deleted posts); otherwise it destroys them. Historical authorship therefore already constrains cleanup.
- `assets/javascripts/discourse/components/ai-agent-llm-selector.gjs`, `resetTargetRecipients`: model selection changes the PM recipient to the model user's username.
- `lib/agents/bot.rb`: initialization accepts an explicit model but falls back to `guess_model`, which resolves a model by user ID.
- `lib/ai_bot/playground.rb` and `entry_point.rb`: routing, PM membership, preferred bot identity, and sharing depend on these users.
- `app/models/ai_agent.rb`, `create_user!`: a separate agent identity path creates TL4 users without the model factory's explicit staff flags.
- `lib/ai_bot/playground.rb`, `ai_custom_fields`: response metadata already includes model display name, model ID, and agent ID.

The architectural rationale is reuse of user-based authorship, addressing, membership, and notifications, with user identity also acting as a model-selection key. This explains the current mechanism, not its original historical intent.

Staff flags deserve a focused permission audit. ToolRunner can resolve a Guardian from a bot user, but that alone does not establish an exploitable vulnerability or prove that removing flags is behavior-preserving. Speaker identity, initiating-user authorization, and explicit privileged automation must be distinguished.

## Alternatives

| Alternative | Benefit | Principal tradeoff |
| --- | --- | --- |
| One dedicated assistant user; explicit agent/model selection | Stable identity, no per-model account proliferation | Distinct agent mentions, blocking, moderation, and chat identity need product decisions; all execution paths must enforce agent/model access |
| Users only for explicitly published agents; models are configuration | Reuses existing agent identities and native mentions/PM membership | Still creates users for published speakers; historical model-addressed conversations need compatibility handling |
| First-class nonhuman actors in core, separate from Users | Removes the underlying human-account assumption | Broad authorship, membership, Guardian, notification, chat, API, and ecosystem work; not a plugin-local cleanup |

The first two eliminate per-model users, not all user records. Only the third can remove User-backed AI identities altogether. A new actor abstraction is not automatically more secure: permissions still need explicit design.

## Group review synthesis

Gemini, Grok, and Opus favored published-agent identity first, singleton assistant second, and core actors last for near-term delivery. Muse challenged that ranking for an assistant-first product: a singleton is cleaner when separate named bots are not the intended experience. Reviews were source-based, not runtime security verification or implementation estimates.

Do not adopt suggestions to call migration trivial, rewrite historical authorship wholesale, seed one permanent agent per model, or remove staff flags without auditing dependent operations. Those either underestimate compatibility or reproduce the existing proliferation under another name.

## Recommended pitch

Models are engines, agents are behavior, and speakers are explicitly published identities.

Use a shared default Assistant for ordinary AI conversations. Let administrators deliberately publish a named agent when it needs its own mentions, avatar, or community role. Models never create speakers. Switching a model changes the engine, not the recipient. Preserve the actual agent/model used on every response using existing provenance fields where suitable.

Implementation boundaries to investigate before coding:

1. Replace model-as-recipient routing with explicit, server-validated agent/model selection across PMs, chat, topic mentions, jobs, retries, sharing, and API entry points. Define conversation defaults separately from per-response provenance and in-flight request selection.
2. Preserve existing post authors and old user records needed for history. Resolve legacy PMs through a compatibility path; add a replacement speaker only after checking topic access and agent/model availability. Do not silently widen PM access, merge conversations, or force every old conversation read-only.
3. Stop new companion creation only after the new routing path works. Retire legacy routing separately from historical attribution; handle old mentions and queued jobs deliberately.
4. Audit tool authorization and staff-dependent behavior. A dedicated assistant must not reuse the general system user or inherit blanket staff privileges merely to participate in conversations.
5. Cover configuration-without-account-creation, model switching with stable authorship, server-side agent/model restrictions, legacy PM continuity, unavailable models, retry provenance, loop prevention, and private sharing boundaries.

No application code or database records were changed for this assessment.
