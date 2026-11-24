# A11y announcement history

A plan for letting the dev-tools a11y inspector (#42289) pair live-region deliveries with the
`announce` calls they contain, now that the `a11y` service combines same-tick calls.

Status: steps 1 and 2 done 2026-10-08. Step 1 is the service history and its nine tests, each
checked against a planted defect. Step 2 is the inspector side, proven on the temp merge branch by
four composition tests. The service is ported onto #44401's TypeScript `a11y.ts` (see "Landing
order").

## The problem

The `a11y` service combines `announce` calls made in the same tick into one live-region write,
joined with the translatable `a11y_announcement_separator` (see "Layer 2 is held on this branch"
in `PR-SPLIT.md`). The inspector assumes one call produces one delivery: when the region changes,
it pairs the first waiting call for that region and compares texts
(`static/dev-tools/a11y/instrumentation.ts`, `recordDelivered`).

So a correct combined announcement reads as two problems. Confirmed on a temporary merge of this
branch with #42289 (2026-10-08): two same-tick calls, "Added Banana" and "You can only select 2
items", produce one delivery of both, and the inspector raises `announce.text-mismatch` on the
delivery and `announce.undelivered` for the second call.

The inspector cannot fix this alone:

- Splitting the delivered text on the separator misfires when a message contains the separator
  ("Saved. Reload to see changes"), and in Chinese and Japanese the separator `。` is in nearly
  every message.
- Joining the waiting calls and comparing would avoid splitting, but only by copying the service's
  other rules (merging identical messages, the restatement filter, an empty `announce("")`
  discarding the queue) into the dev tool, where they would drift.

So the service records what it combined, and the inspector reads that history.

## Design

### `announce()` returns a call id

`announce` returns a number that increases with every accepted call. A call that throws during
validation gets no id. Existing callers ignore the return value today, so nothing breaks.

### A capped, read-only announcement history

The service appends one `AnnouncementRecord` per write it makes to a live region on behalf of
`announce`, keeping only the newest `ANNOUNCEMENT_HISTORY_LIMIT` (50). Region clears from the
auto-clear timer are not recorded: no call caused them.

```ts
interface AnnouncementRecord {
  /** Increases with every write. */
  id: number;
  type: "polite" | "assertive";
  /** Exactly what was written; "" for a clear. */
  text: string;
  /** Calls whose message is in `text`, including identical calls merged into one. */
  delivered: readonly number[];
  /** Calls from the same tick that did not make it into `text`, and why. */
  dropped: readonly { call: number; reason: "restated" | "cleared" }[];
  /** Set when a newer announcement cancelled this write before it was heard. */
  superseded: boolean;
}
```

It is exposed through the `announcementHistory` getter, which returns frozen copies, so
a reader can never change the service's state. The history is always on: dev tools load by default only
in development, but `enableDevTools()` turns them on in production (`initializers/dev-tools.ts:31-43`),
so a `DEBUG`-only history would silently break the inspector there. The cost is one small record per
write in a capped list.

No events or callbacks, and nothing about what gets announced changes.

### How each path is recorded

All in `frontend/discourse/app/services/a11y.ts` on this branch:

| Path | Where | Record |
|---|---|---|
| Calls combined | the `next` callback in `announce` (`:377`, record at `:409`) | one record, every call id in `delivered` |
| Identical calls merged | the `new Set(...)` at `:390` | every call id in `delivered` |
| Restated message dropped | the restatement filter after `:390` | its call in `dropped`, reason `"restated"` |
| Empty `announce("")` | the clear branch at `:331` | a `""` record: the clearing call in `delivered`, the discarded queued calls in `dropped`, reason `"cleared"` |
| Repeat cancelled before its write-back | `setMessage`'s repeat path (`:160`, restore stored at `:162`) and `cancelRestore` (`:203`) | the earlier record's `superseded` becomes `true` |

To make the last row work, the pending buffer stores call ids next to messages, and the restore
timer remembers which record it belongs to, so `cancelRestore` can mark that record.

### The inspector side (#42289)

- `installA11yTap` (`instrumentation.ts:1081`) captures the id `announce` returns and stores it on
  the recorded intent.
- `recordDelivered` (`:527`) finds the newest unpaired record in `announcementHistory` with the same
  type and text and pairs every intent in its `delivered` list.
- Intents in `dropped` get informational findings instead of `announce.undelivered`. That means two
  new rule ids registered in the catalogue (`findings.ts`, next to `announce.undelivered` at `:49`),
  for example `announce.restated` and `announce.cleared` at the `"noted"` tier, with their strings.
- `announce.undelivered` (`scheduleUndelivered`, `:428`) remains for calls that appear in no record,
  or whose record was superseded.
- `announce.text-mismatch` (`:568`) compares the delivered text with the record's `text`.
- The undelivered deadline also checks the history before reporting. An `announce("")` on a region
  that is already empty changes nothing in the DOM, so no delivery fires; its `""` record is what
  shows it arrived. The same check notes a call the history lists as `dropped`.
- The inspector reads the history through a closure over the tapped service and types it with the
  exported `AnnouncementRecord`.

Line numbers in this section are #42289's `instrumentation.ts` and `findings.ts` at `a7b3a70fc74`.

## Tests

Test-first on the service, in this branch's live-regions test module. Each should fail before the
change:

1. `announce` returns increasing ids; a call that throws gets none.
2. A lone message produces one record with its text and `delivered: [id]`.
3. Two same-tick messages produce one record with the combined text and both ids in `delivered`.
4. Two identical same-tick messages put both ids in `delivered`. (Catches pairing by text.)
5. A restated message lands in `dropped` with `"restated"`.
6. An empty `announce("")` after queued messages produces a `""` record: the clearing call in
   `delivered`, the queued calls in `dropped` with `"cleared"`.
7. A repeat cancelled by a newer announcement marks the earlier record `superseded`.
8. The history keeps only the newest 50 records.
9. `announcementHistory` returns frozen records; changing one does not reach the service.

Then on #42289: the throwaway probe from the 2026-10-08 temp merge becomes a real test asserting no
findings for a correct combined announcement, plus tests for the `"restated"` and `"cleared"`
findings.

## Order of work

1. Service history and tests, on this branch.
2. Prove it end to end on the temp merge branch (`tmp/select-kit-x-a11y-inspector`), with the
   inspector changes applied there.
3. The inspector changes go into #42289 once this branch's a11y changes reach `main`, since #42289
   is built on `main` and needs the history to exist.

## Other inspector changes for #42289

Found while trying the temp merge branch. These don't depend on the history, so they can go into
#42289 at any time.

- **A collapsed combobox is exempt from `aria-controls`** (2026-10-08). Tabbing into a closed DSelect
  raised `role.missing-attribute` ("Widget should expose the expected ARIA attribute"). DSelect sets
  `aria-controls` only while open, because the listbox isn't rendered while it's closed and the
  reference would dangle. ARIA 1.2 requires `aria-controls` on every combobox, but the ARIA editor's
  draft requires only `aria-expanded`. The fix adds `collapsedComboboxControls` in
  `instrumentation.ts`, called from `requiredAttributeFindings`. It skips `aria-controls` when
  `aria-expanded` isn't `"true"`, and an open combobox without it is still reported. A new test in
  `a11y-cursor-rules-test.gjs`, "a collapsed combobox does not need aria-controls", covers
  collapsed, no `aria-expanded` (the defaulted `aria-expanded` is still noted), and expanded. It was
  red before the fix and caught two planted defects: exempting every combobox, and exempting every
  required attribute on a collapsed one. The comment on the `role.missing-attribute` case in
  `a11y-catalogue-gate-test.gjs` that said there was no carve-out is updated. Staged, not committed,
  on `tmp/select-kit-x-a11y-inspector`.

## Landing order

#44401 converts `a11y.js` to `a11y.ts`. This branch already carries that
file with the history added, so after #44401 merges, merging `main` here resolves `a11y.ts` to this
branch's version, after checking that every line of #44401's file is still present.

## Open questions

- Whether `ANNOUNCEMENT_HISTORY_LIMIT` should be 50. The inspector only needs records newer than the
  oldest call it is still waiting on, which is at most a 100 ms window.
