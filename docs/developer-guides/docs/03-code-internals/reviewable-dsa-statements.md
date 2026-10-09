---
title: Review queue moderation records
id: reviewable-dsa-statements
---

Enable `dsa_reporting_enabled` to retain restrictions applied through the review queue. It is disabled by default. Moderators use the existing workflow; handling and queue visibility remain unchanged. No classification form, timeline note or API submission is added.

The `dsa_statement_of_records` table stores one pending row per affected item and decision. Restrictions on the same item in one decision share a row. Related items share `decision_key` and `reviewable_id`. These links allow a future single classification form per reviewable to cover its affected records. Reopening and handling a reviewable creates another decision. Restoration retains the original record and sets `reversed_at`.

`Reviewable#perform` establishes the recording context. Existing content, topic and account events capture actual effects. Later suspension and silence requests use their existing reviewable reference. Queue edits carry the reference through their existing save. Actions outside the review queue, unrestricted approvals, failed actions and author withdrawals are excluded.

`payload` retains programmatically known SoR API attributes: stable PUID, actual restrictions, dates, content types, territorial scope, initiating source and separate detection and decision automation. `content` retains affected text and title for later assessment, independently of content deletion. Content snapshots are private database evidence and must not be copied into public API payloads without review. Associated reviewable records are retained to preserve moderation context.

These payloads are incomplete. Later classification must supply `decision_facts`, `decision_ground`, `category` and the conditional legal or terms grounds and explanation. No legal conclusion is inferred from a flag. There are no delivery states, credentials, jobs or automatic submissions in this phase. Future delivery must separately validate the full [Commission API schema](https://transparency.dsa.ec.europa.eu/page/api-documentation).

This phase covers review queue restrictions only. Illegal notice intake, authority orders, appeals, moderation outside the queue and annual report generation remain separate work.
