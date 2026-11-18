# Calendar invitation emails (draft)

## Enabling and scope

This is a separate delivery channel from forum notification emails and calendar
subscription feeds. It is off by default, with no backfill of existing invitations.
Enable `event_calendar_invitations_enabled` and configure
`event_calendar_invitations_organizer`, with both event plugin settings enabled.

Only the individual **Invite** action (the username-based `Events::Invite` service)
creates calendar invitations. Group expansion, CSV/bulk invitations, predefined
attendance, self-attendance, and recurring events do not. Explicitly inviting a user
again is idempotent unless their previous calendar invitation was cancelled.

The organizer must be a dedicated mailbox outside Discourse inbound email. It is
used for `ORGANIZER` and `Reply-To`; the usual notification address remains the
email sender. Known group/category/reply-by-email addresses are rejected and
rechecked before delivery. Administrators must ensure custom email headers do not override `Reply-To`, and
external mail forwarding
and catch-all routing cannot deliver organizer replies into Discourse. Changing the
setting does not change existing events' organizer identity, including for later
recipients of those events.

Calendar acceptance/decline does **not** change Discourse attendance. There is no
inbound iTIP/RSVP handler. Email bodies link to the topic to update attendance.

## Lifecycle

Each recipient has a durable row with the event UID, organizer, recipient address,
revision sequence, desired snapshot, and last successfully delivered snapshot.
The UID does not depend on the event start date. Each message contains only its
recipient's attendee address, never the other attendees.

Changes to start/end, all-day mode, name, description, location, event URL or topic
link send a `METHOD:REQUEST` with a higher `SEQUENCE`. Queued intermediate revisions
are coalesced. Unrelated changes such as closing the event do not send mail.

Event destruction (including removing event markup), post soft deletion, conversion
to recurring, and destruction of an existing attendance record cancel outstanding
calendar invitations. Cancellation survives event deletion and uses only the last
delivered details. Recovery or conversion back to non-recurring does not reinvite
people automatically: use the individual Invite action again. An invitation that
has never been sent needs no cancellation email. Expiry/closing alone is not a
cancellation.

Attendance and explicit invitations are separate. This draft has no new recipient
management UI: an invitation without an attendance record cannot be individually
revoked through the attendee list. Bulk `delete_all` paths, including private-group
attendance pruning, do not invoke the attendance-destruction callback. Topic access
is checked before every request; loss of access turns a pending request into a
cancellation using previously delivered data. Access changes alone do not trigger
an immediate calendar cancellation.

## Delivery and privacy

A dedicated job uses `Email::Sender`, independently of whether the user is online
or has already read the post. `email_level = never`, inactive accounts, suspension,
silencing, staged/bot accounts, bounce limits, global email disabling, and
`private_email` prevent delivery. The `only_when_away` preference does not delay
calendar maintenance; it is treated as permission to receive calendar email.
Disabling the feature/plugin or clearing the organizer setting stops all delivery,
including cancellations. Re-enabling resumes pending revisions; initial invitations
are not sent after their start time. No production setting is changed by installation.

Recipient addresses are frozen; a changed account email stops delivery to the old
address rather than leaking updates to it. This draft does not migrate invitations
to a new email address. User destruction removes that user's ledger rows.

Delivery is serialized per recipient, and only a successful core email log advances
the delivered revision. A ten-minute sweep requeues pending revisions if enqueueing
or delivery failed. SMTP and the database cannot commit atomically: a crash after
SMTP acceptance but before recording success can resend the same UID/sequence.
Normal job retries and repeated Invite actions do not duplicate successful sends.
Suppressed recipients remain pending; there is not yet an age-based ledger retention
policy or a delivery-status admin UI.

## Calendar format and verification

Timed values are emitted in UTC. All-day values follow the event model's date-only
UTC representation with an exclusive end date. Open-ended timed events use a
one-hour duration. Content is escaped, UTF-8 lines are folded at 75 octets, and the
calendar attachment is base64 encoded to preserve CRLF. The final message is
`multipart/mixed`, with a text/HTML alternative and a recipient-specific
`text/calendar; method=REQUEST` or `method=CANCEL` attachment.

Specs exercise the real mailer and core sender and parse final MIME. Actual calendar
client behavior, including organizer authentication, RSVP controls, update handling,
and cancellation removal, still needs end-to-end validation in supported clients
before this draft is ready to ship. No real calendar-client validation is claimed.
