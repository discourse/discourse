# Reviewable outcome reporting

A reviewable can be handled more than once. `reviewable_outcomes` stores one row
per reviewable and updates it after each handling. The
`reviewables.type_source` creation metadata is unchanged.

## Data

Each row has a unique reviewable ID, `outcome_source`, `legal_basis`, nullable
`restriction_type` string array, and timestamps. The source is `human` for a
staff decision and `automated` for AI, a job, or another automated decision.
The basis is `illegal content` when `potentially_illegal` is true at the latest
handling; otherwise it is `tos_violation`.

The array contains each category actually applied by the handling:

| Action | Code |
| --- | --- |
| Post or topic deleted | `visibility_restriction_removal` |
| Post hidden | `visibility_restriction_disable` |
| User suspended or silenced | `account_restriction_suspension` |
| User deleted | `account_restriction_termination` |

A decision that applies none stores SQL `NULL`. A later handling replaces the
earlier source, basis, and restriction array. Confirmed restrictions that follow
that handling are added to its array. Categories are deduplicated; the table
reports restriction types, not the number of affected posts.

## Write flow

`reviewable_outcome_reporting_enabled` is server-side and defaults off. With it
off, handling does not create outcomes. Disabling it later leaves prior rows
queryable.

`Reviewable#perform` emits a handled event for a successful transition out of
pending in its existing transaction. The event compares the affected post,
topic, and user before and after the action, so a deletion followed by an
`ignored` status still reports removal, while a failed user deletion does not
report termination.
Callers pass decision provenance explicitly for known automation paths. Direct
reviewable transitions record automated handling.

An initializer receives those events and calls two Discourse `Service::Base`
services that own writes:

- `Reviewable::RecordOutcome` validates source and creates or updates the row
  with the latest legal basis and confirmed restrictions.
- `ReviewableOutcome::AddRestrictions` finds the row by reviewable ID, checks
  the affected user, and adds confirmed, deduplicated categories.

Suspension and silence happen in a separate request after some reviewable
actions. These requests already carry the reviewable ID. The central
suspension, silence, and post deletion methods report confirmed actions, and
the listener updates that reviewable's row. A failed action leaves the
restriction array unchanged.

The modal's `delete_all` option starts a separate batch request or background
job after the penalty. The server finds the reviewable ID in the recent staff
penalty history and adds removal only after at least one post is deleted.

## Data Explorer example

```sql
SELECT reviewable_id, created_at, outcome_source, legal_basis, restriction_type
FROM reviewable_outcomes
WHERE outcome_source = 'automated'
  AND 'visibility_restriction_disable' = ANY(restriction_type)
ORDER BY created_at DESC;
```

Verification is focused on setting off/on, both sources and bases, replacement
after reopening, no action, content removal and hiding, successful and blocked
user deletion, and multiple categories from one penalty.
