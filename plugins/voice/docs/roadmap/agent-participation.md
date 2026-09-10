# External agent participation

## Problem and agreed scope

An external worker can join the media server without appearing or becoming audible
in Voice. This is deliberate in the original design: Discourse owns the roster
instead of importing the media server's participants. This change admits explicitly
authorized external agents while preserving the existing human presence path.

Agreed product decisions:

- Initially support agents in LiveKit rooms. Do not switch mesh calls automatically.
- Administrators associate an integration with an existing bot account and allowed
  rooms. Support valid negative user IDs; zero and arbitrary numeric identities
  are not authorization. There is no dependency on the AI plugin.
- A customer runs their worker. An integration credential is exchanged for a
  short-lived, room-scoped media token. Worker deployment and managed dispatch are
  outside this change.
- Discourse authorizes the account, room, and listener/speaker role. Verified
  provider events establish presence for an authorized agent session only.
- Agents appear in the shared roster and use the existing media/role controls.
- Room moderators can exclude an agent for a duration or indefinitely. Exclusion
  survives reconnects; admins can restore access.
- Agents do not consume human room capacity or contribute to human attendance,
  badges, co-presence, or participation statistics. Provider resource usage remains.
- Agents leave when the last human leaves. No agent admission into an empty room.
  Integration authorization survives the call; exclusions remain effective.
- Keep authorization and moderation independent of the media provider. Additional
  providers require adapters and frontend transport support, not just endpoints.

## Authorization and lifecycle contract

1. An admin creates a revocable integration credential scoped to a bot and rooms.
   Store only a digest; reveal the secret once. Normal admin endpoints retain
   session authentication and CSRF protection.
2. A machine endpoint authenticates the integration credential, checks the room's
   active transport, human presence, role, and exclusions, and records an authorized
   session before returning connection credentials. Never accept a caller-selected
   identity as proof of authorization. Do not expose the media server API secret.
3. Verified provider connection events activate only that authorized session.
   Unknown participants never create Discourse membership. Human webhook handling
   remains reconciliation-only.
4. Connection identity/session correlation must prevent stale joins/departures or
   reused credentials from reviving superseded or excluded sessions.
5. Periodic reconciliation maintains agent presence without browser heartbeats and
   removes stale connections. Human departures and expiry end agent participation
   when the room has no humans. External failures must not revive roster access.
6. Exclusion revokes authorization before disconnecting media. Self-hosted LiveKit
   does not revoke an already issued token when removing a participant: short token
   lifetimes, roster gating, and re-eviction limit reuse but do not guarantee zero
   transport access between reconnection and enforcement. Document this limitation
   honestly; token expiry alone is not a strict immediate revocation mechanism.

## Implementation plan

- [x] Backend: durable integration/exclusion storage, admin API, credential exchange,
  authorization, provider credentials and lifecycle reconciliation.
- [x] Shared presence: authorized negative IDs, separate human capacity/accounting,
  roster serialization and last-human cleanup across leave, kick, and expiry.
- [x] Frontend: negative-ID media support, admin integration management, and agent
  exclusion duration controls using existing UI primitives and FormKit.
- [x] Automated tests: unauthorized identity/room/token rejection; credential revocation;
  role grants; webhook replay/supersession; missed events; empty-room cleanup;
  exclusion reconnects; human accounting/capacity; negative-ID audio and rendering;
  unchanged mesh/human behavior.
- [x] Review complete diff, run focused Ruby/JS tests and required lint, and record
  actual validation results and remaining limitations below.
- [x] Update operational documentation. Preserve this spec when preparing the PR.

## Historical rationale for reviewers

- Resenha c84cdca8f6a1 (#50): Discourse identity and Guardian token authorization.
- Resenha 32516ef7738c (#58): numeric identities and roster-driven media eviction.
- Resenha 8f7d11cbc207 (#56): webhooks cannot invent presence.
- Resenha 0c5460e4f592 (#72): session-ID bookkeeping for delayed departures.
- Discourse 89bcc0f498cf (#43044): bundled Resenha as Voice.

The new exception is provider-maintained presence for explicitly authorized agents;
it is not general provider authority over room membership. Existing AI bot accounts
use negative IDs, whereas staged accounts are a separate account property.

## Validation and implementation notes

The implementation adds durable integration, room scope and exclusion records;
the migration and schema dump are included. Bot selection uses existing negative-ID
accounts, excluding the system account. Bot creation and managed worker dispatch
remain outside scope.

Agent admission uses an opaque Redis session proof embedded in token metadata.
Signed webhooks request a current provider snapshot rather than trusting the event
to create or delete presence. Reconciliation rechecks room scope, revocation,
exclusions and human presence. Listener/speaker permission is capped by the admin's
integration role; room moderation may demote a speaker. Integration edits, rotation
and revocation invalidate existing admission proofs.

The SFU callback writes directly into the remote-stream registry, whereas mesh
tracks use a separate media-policy helper. Agent role/admission checks therefore
also run at the SFU callback. Tracks received before roster admission are restored
after admission; demotion and exclusion remove them. Human SFU behavior is preserved.

Validation completed so far:

- Non-system Voice RSpec suite: **820 examples, 0 failures**.
- After final fallback and orphan-session cleanup changes: focused controller,
  agent-manager and orphan-session specs: **52 examples, 0 failures**.
- Signed-webhook suite, including agent admission, stale departure, revocation and
  exclusion replay: **28 examples, 0 failures**.
- Focused browser suite (`voice-webrtc-livekit`, `VoiceAgentIntegrations`,
  `VoiceKick`): **22 tests, 0 failures**. An initial browser launch stalled before
  executing tests; a fresh run completed.
- Test database migration, schema dump and model annotations completed.
- Required `bin/lint --fix` passed for all changed Voice files; `git diff --check`
  passed. Unrelated workspace edits were left untouched.

The credential exchange and operations are documented in [LiveKit setup](../livekit.md#external-agents).
Real-provider end-to-end agent audio and multi-browser/system tests have not been
run for this change. Exercise those before deployment, including last-human leave,
token reuse after exclusion, delayed webhooks and provider outages. The transport
revocation limitation above remains; authorization and disconnect operations also
span the database, Redis and the provider rather than forming one atomic operation.
