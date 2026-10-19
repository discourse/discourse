# Workflow verification

## BACKLOG

BACKLOG is idle. Cards in this column do not start coding work.

## TODO

Moving a card to TODO starts work in a fresh capybara checkout inside Docker.
The card's Discourse topic supplies the task context: read the topic replies,
including corrections, and the images attached to those replies before implementing
the latest complete request.

## REVIEW

REVIEW hands off the card preview instance for verification. Both impersonation
links point to that same card preview instance:

- Admin account: `NGROKURL/session/admin-account/become`
- User account: `NGROKURL/session/user-account/become`

Replace `NGROKURL` with the card preview instance URL. There is no separate board
impersonation link in this handoff.

## DONE

DONE completes squash integration of the card changes, followed by a rebase onto
the official upstream and a Docker board restart.

## Image verification

The image attached in the topic reply reads exactly: `CAPYBARA IMAGE 742`.
This transcription verifies that reply images are included as task context.
