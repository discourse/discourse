# External agent implementation review

Reviewed commit `a5202ed48e6` against its parent on 2026-09-14 with three
independent reviewers covering authorization, lifecycle, and frontend behavior.
The findings below describe the reviewed commit. The follow-up implementation
addresses all four; implementation and validation details follow the findings.

## P1: Expired transport pins prevent agent disconnection

`AgentManager.evict_agents_in_room!` (lines 128–134) removes roster entries and
session proofs, then delegates provider removal to `RoomServiceClient`. That
client silently skips mutation requests unless the room still has a LiveKit
transport pin (`sync?`, lines 79–84).

Only human request paths refresh that pin. Its default lifetime is 60 seconds,
while participant reconciliation runs every minute. If the final human crashes
and the pin expires before the next sweep, cleanup removes the bot locally but
sends neither RemoveParticipant nor DeleteRoom. Later reconciliation also stops
because the pin is absent, leaving the provider connection alive indefinitely.
This is distinct from the documented reuse of an issued token after removal:
here the existing connection is never removed.

A focused Ruby harness using the actual manager and provider client with an
expired-pin tracker confirmed that roster removal sends zero provider RPCs.
Keep a durable cleanup obligation identifying the provider independently of the
short-lived presence pin, and retry failed cleanup. Preserve mesh isolation.
Add a last-human crash regression that expires the pin before the sweep and
asserts a provider disconnect is attempted.

## P1: In-flight reconciliation can restore excluded agents

`AgentManager.reconcile` (lines 151–159) verifies the admission proof, then
separately refreshes its expiry and writes participant presence. Exclusion or
revocation can delete the proof and remove the bot between those operations.
Reconciliation ignores the failed expiry refresh and re-adds the bot, its role
metadata and its roster entry after the exclusion has completed.

The actual reconciliation method with an interleaved revocation stub reproduced
a failed proof refresh followed by restored agent presence. This restores frontend
audio eligibility until further reconciliation, independently of the documented
provider token-reuse limitation.

Commit presence only while the same admission proof is current, atomically
coordinated with invalidation. Another non-atomic authorization check leaves the
same race. Add a regression interleaving exclusion with reconciliation.

## P2: Agent microphone subscriptions are not restored

`LivekitRoomSession.restoreParticipant` (line 317) delegates subscriptions to
`#applyDesiredSubscription`, which returns immediately for microphone tracks.
However, `dropParticipant` explicitly unsubscribes all publications.

When roster admission temporarily disappears while the provider connection
survives, readmission cannot resubscribe the retained microphone publication.
The agent appears as a speaker but stays inaudible until it reconnects or
republishes. Demotion/promotion can also encounter this when publications survive.

Explicitly restore permitted microphone subscriptions while preserving video
watch gating. Make the regression clear `publication.track` on unsubscribe and
require a subscription to restore it. The existing lifecycle test uses a no-op
`setSubscribed`, retaining the original track and masking the failure.

## P2: Rejected admin edits still change room authorization

`AdminAgentIntegrationsController#update` (line 27) assigns the `rooms:` collection
before bot immutability and model validation. Rails persists replacement of an
existing has-many-through collection immediately, in its own transaction.

An edit combining changed rooms with an invalid name or forbidden bot change
therefore changes durable authorization even though the request returns an error.
The subsequent session eviction is skipped. This was confirmed against the
controller and the installed Rails association implementation.

Wrap assignment, immutability validation and save in one database transaction;
evict sessions after successful commit. Add rejected-update regressions that
assert room scope and authorized sessions remain unchanged.

## Validation limits

The initial review used code inspection and the focused harnesses described above.
Real-provider end-to-end testing remains outstanding as recorded in the
[implementation plan](./agent-participation.md).

## Follow-up implementation

- Track rooms with issued agent sessions independently of expiring transport pins.
  Keep that cleanup obligation after provider failures and retry on subsequent
  participant sweeps. Rooms without agent obligations retain transport isolation.
- Commit agent presence and refresh its proof in one Redis script that compares
  the original proof. Revoke the proof and presence atomically, so an in-flight
  reconciliation cannot restore revoked admission.
- Restore microphone subscriptions when roster eligibility returns, while keeping
  video subscriptions subject to watch state. The regression simulates asynchronous
  track restoration after unsubscribe.
- Wrap admin attribute assignment and validation in the save transaction, so
  rejected edits roll back room authorization and preserve admitted sessions.

The focused LiveKit frontend suite passes all 20 tests; the agent manager and admin
integration request specs pass all 19 examples when run alone. Changed Ruby and
JavaScript files pass `bin/lint --fix`. The sequential Voice Ruby suite excluding
system specs passes all 829 examples. A broader run was interrupted after an
overlapping test process caused database contention; it is not a clean full-suite
validation.
