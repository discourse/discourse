---
title: Review queue statements of reasons
id: reviewable-dsa-statements
---

Enable `dsa_reporting_enabled` to record restrictions applied through the review queue. Reporting starts when enabled and does not backfill earlier decisions. Configure the API token and sandbox or production environment separately. API credentials are never serialized to the browser.

## Moderator workflow

Moderation takes effect immediately. A handled reviewable remains visible until staff select a community rule and EU category. Saving records a timeline note and queues its statements for delivery. The normal reviewable status does not change during classification.

The rule mappings describe Discourse's default guidelines and terms. Operators must ensure their published rules match these mappings before enabling reporting. Selecting a rule asserts that its description accurately explains the decision. The category remains a separate moderator choice.

Illegal content reports use `illegal_content_reporting_url` in the flag modal. Historical illegal flags remain readable. New illegal flags are rejected for posts and chat messages.

## Recording boundary

`Reviewable#perform` establishes a recording context around the moderation transaction. Shared deletion, edit, topic status and account penalty events record actual effects within that context. Later suspension and silence requests use their existing reviewable reference. Queue edits carry that reference through the composer save. Cancelled penalties and approvals without restrictions produce no statement.

The separate `dsa_statement_of_reasons` table retains affected item metadata, decision identity, classification, payload and delivery state. Each affected item has its own statement; statements from one decision share classification. Reopening a reviewable creates a distinct decision. Reporting rows survive deletion of their source records.

Post and topic deletion map to removal; hiding maps to disabling access; unlisting maps to demotion; closing maps to restricting interaction. Account suspension and termination have account restrictions. Silence partially suspends service provision. Avatar removal records an image restriction. Rejected publication disables access to the submitted content.

Content dates come from the affected item, or the voice session's joining time. Queued content uses its submission time. Media types come from stored markup; embeds without a known media type use `CONTENT_TYPE_OTHER`. This does not detect whether media was synthetically generated. Account registration decisions use the account creation date. Global restrictions include all EU and EEA territories.

Ordinary member flags use `SOURCE_TYPE_OTHER_NOTIFICATION`. Staff or system initiative uses `SOURCE_VOLUNTARY`. Automated detection and decision making are separate. Staff API and MCP actions remain human decisions; AI execution establishes explicit automation provenance. An approved AI tool proposal records a partially automated decision.

## Delivery and recovery

Sidekiq submits at most 100 classified statements per request. A tenant lock prevents overlapping workers. Each attempt leases rows for 30 minutes. Temporary errors retry with bounded delay. Stable PUIDs and reconciliation prevent an uncertain delivery from being submitted twice. A statement retains its first delivery environment when settings change.

Administrators find permanent failures through the existing queue's Submission failed filter. They can correct classification or retry after repairing credentials. Unknown required metadata remains a visible failure. Submitted payloads cannot be reclassified.

The scope covers review queue restrictions. Dedicated illegal notices, authority orders, complaints, appeals, moderation outside this queue, and annual spreadsheet generation require separate workflows. These records alone do not establish complete DSA compliance.

The payload follows the [Commission API schema](https://transparency.dsa.ec.europa.eu/page/api-documentation) and [attribute explanations](https://transparency.dsa.ec.europa.eu/page/additional-explanation-for-statement-attributes).
