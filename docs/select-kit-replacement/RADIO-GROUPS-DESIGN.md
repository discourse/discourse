# Group-exclusive ("radio") selection — design

Status: **designed, not implemented**. This document specifies the behavior so the
implementation cycle starts from a settled contract. It builds on the unified grouping model
(`@groupBy` is the only structural primitive; labels decide header vs splitter presentation).

## Problem

A multi-select sometimes holds values that are mutually exclusive within a category while
freely combinable across categories: one priority but many labels, one tag from a
one-per-topic tag group alongside unrestricted tags. The exclusivity rule itself lives only
server-side today: for tags, the search endpoint excludes or disables conflicting
`one_per_topic` candidates per query, so the legacy pickers surface the rule as missing or
disabled rows — but the generic select engine has no client-owned group-exclusivity model,
cannot express the rule for plain client sources, and cannot perform *replacement* semantics
(picking the new value evicts the old one) anywhere. This design is that model: selecting an
option evicts its group-mates from the value at the moment of selection.

## Semantics

- Multi-select only (`@multiple={{true}}`). Single-select is trivially exclusive already, and
  the option is rejected with a debug assertion elsewhere.
- Selecting an option whose group key `K` is exclusive removes every held value whose resolved
  item shares `K`, then appends the new value. One `onChange` emission carrying the final
  array — never an intermediate "removed" emission followed by an "added" one.
- Deselection is unchanged. Toggling an already-selected exclusive option deselects it like
  any other row.
- Options whose group key is nullish are never exclusive with each other: "no group" is the
  absence of a partition, not a shared partition.

## API

```ts
// SelectEngineOptions / DSelect args
groupBy?: string | ((item: SelectItem) => SelectItemId);   // existing — same key space
exclusiveGroups?: boolean | SelectItemId[] | ((key: SelectItemId) => boolean);
// true            → every group is one-of
// [keys]          → the listed group keys are one-of
// (key) => bool   → dynamic predicate
```

`exclusiveGroups` requires `groupBy`; passing it without one fires a debug assertion.
Exclusivity is deliberately **not** a per-item marker: it is a property of the key space, and
reusing the `groupBy` key means the visual grouping and the exclusion partition can never
disagree. A consumer that wants exclusion without visible boundaries can supply `groupBy`
with `groupLabel` omitted on an unsorted list — but the partition and the presentation are
one concept, on purpose.

## Where it lives

`selection-actions.ts#select()` is the single chokepoint — pointer, keyboard,
create-on-the-fly, and the compat bridge all funnel through it, which is the same argument
that placed `maximum` there. Two collaborators move to make that possible:

- The group-key function becomes shared: extract `ListComposer.#groupKey` into
  `SelectOptionsView.itemGroupKey(item)` so the composer and the selection actions read one
  definition and cannot drift.
- The exclusivity predicate (normalized from `boolean | keys[] | fn`) is exposed on the
  options view beside it.

In `select()`, the multi branch becomes: resolve each held value to its item, drop the ones
sharing the new item's group key, append, emit. Value→item resolution needs no new plumbing:
`SelectionActions` already receives a `resolveOneSync` callback (the value resolver's cache +
client corpus; the engine exposes the same seam to the announcer as `resolveSingleSync`).
**An unresolvable held value is never evicted** — its group is unknowable, and silently
dropping data on a cache miss is worse than a temporarily over-full group; the rule is
enforced again on the next selection in that group once the value resolves.

## Interaction with `@maximum`

Evaluate the cap against the **post-eviction** count. Replacing a group-mate at the cap is a
swap, not growth, and must succeed: compute the eviction set first, refuse only if the
resulting array would still exceed `maximum`. (Today's check runs before any group logic and
would wrongly block the swap.)

## ARIA

The listbox stays `aria-multiselectable="true"` with `role="option"` rows. Exclusivity is
application behavior, not a widget-role change — `role="radio"` inside a listbox is invalid
and would mis-announce the interaction model. What the reader needs is the *consequence*:
the announcer should speak the replacement ("X selected, Y removed"). Two pieces of existing
plumbing get it most of the way but both need extending: `diffValues` returns only the
*first* added and removed value (an eviction can remove several, e.g. seeded duplicates), and
the announcer's `valueChanged` takes mutually exclusive added/removed branches, so a swap
currently announces only the addition. The eviction path must produce a combined
announcement, not rely on the existing branches.

## Edge cases

- **Seeded duplicates**: a `@value` seeded with two same-group ids is never trimmed on mount —
  the same principle as a value seeded over `@maximum` (displayed and removable, never
  destroyed). The rule is enforced on the next selection in that group.
- **Create-on-the-fly**: a created item gets its group key from `itemGroupKey` like any other
  item; a nullish key means non-exclusive.
- **Server sources**: exclusion works — it keys off items, not off the rendered list — even
  though *visual* grouping stays client-only. Document the asymmetry: a paged picker can
  enforce one-per-group while drawing no boundaries.
- **Controlled-value races**: the compat bridge routes its `select(value, item)` through
  `engine.select()`, so it gets eviction for free — the chokepoint really is single. What can
  land over the rule is the same race `maximum` documents: a consumer that applies the emitted
  value asynchronously or merges it additively can hold two same-group values until the next
  selection in that group re-enforces the rule. Quote the `maximum` doc rather than restating
  it.

## Prior art

- Discourse exclusive tag groups (`one_per_topic`) — the rule lives server-side
  (`lib/discourse_tagging.rb`, `app/services/tags/search.rb`): the search excludes or
  disables conflicting candidates per query, so the legacy picker blocks the second pick
  rather than replacing the first. A tag-picker adapter could map tag-group membership to
  `groupBy` + `exclusiveGroups` and upgrade "blocked" to "replaced".
- Old select-kit has no client-side equivalent; the closest idiom is the `maximum === 1`
  slice, which is whole-control, not per-group.

## Test surface (for the implementation cycle)

- Eviction on select: same group evicts, different group appends, nullish key never evicts.
- One emission per selection, carrying the final array.
- Swap at `@maximum` succeeds; growth past it is still refused.
- Unresolvable held values survive an exclusive selection.
- Seeded same-group duplicates survive mount and resolve on next selection.
- Announcement carries both halves of the replacement.
