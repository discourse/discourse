# LiveKit agent participation

## Product contract

- `voice_livekit_agent_enabled` creates one negative-ID bot, `livekit_agent_bot`.
  Disabling preserves the account; enabling again reuses it. An existing unrelated
  account with that username is never adopted.
- The invite modal accepts an agent dispatch name for each invitation. The feature
  uses the existing LiveKit Cloud project credentials and dashboard deployment.
- Members of `voice_livekit_agent_invite_allowed_groups` (admins by default, admins always
  included) explicitly invite the bot through a public Voice room's menu, including the widget
  menu. A human must already be present, and the call must already use LiveKit.
- The bot speaks and listens. Room managers can kick it without a timed exclusion;
  inviters can immediately invite it again. Private rooms and mesh calls are outside
  this feature's scope.
- Bots leave when the last human leaves and do not contribute to human capacity,
  attendance, co-presence, badges, or statistics.
- No integration records, custom worker credentials, room allowlists, role fields,
  or exclusion management are needed. The single bot ID uses PluginStore.

## Authorization and lifecycle

The invite endpoint uses normal session authentication, CSRF protection, and
Guardian invite-group/public-room checks. The dispatcher independently requires the
feature, a configured Cloud project and a valid invitation name, an active bot, human presence, and a
LiveKit transport pin.

Every invitation writes a new opaque Redis admission proof. An authenticated
provider snapshot must match the dispatch ID, room, agent name, and metadata and
report exactly one running job identity. The participant must have the provider's
agent kind. Neither a participant's claimed metadata nor its display name is
sufficient. Clients receive the verified identity mapping in roster metadata.

Provider permission updates precede roster admission. A Redis compare-and-set
checks that the authorization proof remains current when committing presence;
a concurrent kick or changed setting cannot restore a stale session. Signed
webhooks trigger reconciliation rather than importing event payloads as members.
The scheduled sweep reconciles missed events and expires absent agents.

Kicking revokes local authorization before cancelling the provider dispatch.
Cleanup records remain separate from admission proofs, allowing deletion retries
and recovery of dispatch creation whose response was lost. Room cleanup resolves
session keys from the room's dispatch records and the shared bot, without scanning
Redis. The scheduled sweep also retries provider cleanup for deleted rooms using
their retained IDs; successful cleanup removes them from the provider-room index. A new invitation
supersedes earlier sessions. Disabling the feature revokes current sessions. Last-human cleanup also handles pending dispatches.

LiveKit supplies the initial permissions for managed agents. Discourse updates
these before admitting playback, but this does not prevent provider access before
reconciliation. Use trusted dashboard deployments. Audio conversation is supported;
provider data publishing is disabled. Outages can delay remote disconnection.

## Hosting and testing

LiveKit's Agents framework supports Cloud and self-hosted servers, while Agent
Builder and managed hosting belong to Cloud. This implementation targets Cloud
only. The [operations guide](../livekit.md#livekit-agent-builder) documents setup,
manual testing, and automated test commands. Backend tests stub provider responses;
real agent audio, deployment readiness, and provider logs require manual validation.
