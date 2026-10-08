# Sandbox accessibility remediation (within Phase 1)

Screen-reader and design feedback on the `DSelect` sandbox, from dev topic **#188731**: an
NVDA pass and a design review. This file tracks the ten approved items, and — more usefully —
records what the cycle *changed about the diagnosis*, because several of the original
conclusions were wrong in ways that cost real time.

See also: [`PHASE-1.md`](PHASE-1.md) (the parent tracker), and the RFC at the worktree root.

> **Last reconciled against the code at `85f0ed17779`** (2026-07-29). Re-stamp when you close
> an item.

Status legend: ☐ pending · ◐ partial · ☑ done · ⊘ deferred to its own cycle

## Items

| # | Reported | Status |
|---|---|---|
| K1 | No way to tell you can type in the combobox, or that existing text is highlighted | ◐ trigger naming shipped; typing ⊘; highlight ☐ |
| K2 | Results not announced as results; "no results" never spoken; inconsistent re-announcement | ☑ entry and filter paths both; the unchanged-set case reopened, see below |
| K7 | Paginated source: Safari reads the set size as 18446744073709551615 | ☐ own cycle; our markup is correct and the options all cost something |
| K3 | "selected" not announced when navigating, but "not selected" is | ☐ two halves: the silence is a platform gap, the "not selected" noise is ours; see below |
| K4 | Tag chips not read on focus or arrow navigation | ☐ own unit |
| K5 | Notification dropdown announces the held value on open, but arrow-nav starts at row one | ☑ |
| K6 | Empty gap where no check appears; wants empty box / checked box | ☑ |
| C2 | Sync typeahead cannot be cleared once an option is chosen | ⊘ |
| C3 | Static select: no focus indicator on click; focus appears on input *and* a row | ◐ |
| C5 | Header-less divider row | ☑ |
| C6 | Toggle-dropdown styleguide example | ☑ |

Out of scope by agreement: C1 (hover parity), C4 (icon-only redo), C7 (the design CSS pass).

## The governing rule, learned the hard way

**Express states in markup; announce only events.**

A state has an element and an attribute that the platform already computes, re-computes on
focus change, and speaks in the reader's own verbosity settings and language: which row is
current (`aria-activedescendant`), whether it is selected (`aria-selected`), how many rows
there are and where you are (`aria-posinset` / `aria-setsize`), open or closed
(`aria-expanded`), the control's name and value. Every one of those we narrate ourselves is a
fact we then have to keep in sync, in one voice, in one order.

An event has no home in markup: an item added while its chip is not focused, more rows
arriving under a stationary cursor, a load failing. Those earn a live region.

This rule is the outcome of the cycle, not its premise. The original plan argued at length
about *how* to deliver announcements reliably — two architectures, several review rounds — and
never asked *whether* each announcement should exist. That unasked question was the one
breaking things.

### Announcement inventory

| Announcement | Verdict |
|---|---|
| Count on listbox entry | **Suppressed when opening seeds a cursor.** The seeded row already says "1 of 15". |
| Count on update while open | **Last resort.** Cursor moved → the row said it. New query, cursor still → ask for the row again. Set unchanged → nothing is said, by either channel. The count survives only where no row can carry it: no cursor at all, or more rows for the same question. |
| `no_results`, `min_chars` | Keep, and `no_results` waits like a count. No row competes with it, but emptying the list breaks the control's own ARIA references, and the reader re-introduces the whole combobox over the top of it. |
| Limit hint (`max_reached` / `min_not_reached`) | Keep. At the cap `shouldAutoActivateFirst` is suppressed (`engine.atMaximum`), so nothing seeds and nothing competes. |
| `filter_to_narrow` | **Flagged.** Fires at entry when reopening a capped list, which is exactly when a cursor seeds. Unlike the count it says something markup cannot, so the resolution may be that the hint wins. Needs one listen. |
| Reveal (`loading_more` / `loading_complete`) | Keep. Events. |
| `item_added` / `item_removed` | Keep. Events. |
| `selection_cleared` | Keep. Event, and clearing has no other channel. |

## Corrections to the original diagnosis

Recorded so nobody re-derives them.

- **K5 was not a windowing race.** The published diagnosis (the seed sees only mounted rows
  while an off-window selection scrolls in a tick later) described a real bug, but not this
  one: the reported control is a six-item `static` list with no windowing at all. The actual
  cause is that `dRovingFocus` installs on a container the virtualizer has not filled yet, so
  the open-time seed runs against **zero** items, clears the cursor, and nothing re-seeds
  (`rovingNonTypeaheadKey` is `filter::atMaximum`, and neither changes when rows arrive).
  Measured in a real browser: `seedSaw: "0", optionsNow: 14, ad: "absent"`.
- **The suite could not see it.** `d-select-test.gjs` already asserted "keyboard opening
  activates the first option" and passed, because rendering tests mount rows before the
  modifier installs. Fixed in `d-roving-focus.ts` with a one-shot `MutationObserver` armed
  only when a seed found *no items at all*; a seed that found items and declined is a
  decision, not an absence, and re-seeding on every item change would throw a reader who has
  arrowed away back to the top of a windowed list.
- **"First option never read" was two announcements racing for one voice.** With the cursor
  finally correct, VoiceOver still skipped the row. Two consecutive opens settled it: the open
  that spoke "15 results" never spoke the row, and the open that spoke the row never spoke the
  count. The live region text mutated on **both**, so nothing was being swallowed at the DOM
  level.
- **Refuted along the way**, each after being stated with more confidence than it deserved:
  `aria-modal` pruning (the probe reports no modal, no `aria-hidden`, no `inert`);
  `role="dialog"` as a hard boundary (it cannot be — the *second* option is read fine through
  the same boundary); the roving modifier's visibility filter (disabling it changed nothing);
  and `aria-owns` on the select-only trigger (added, no audible effect, reverted).
- **K3 is not a markup defect.** The accessibility tree exposes it correctly:
  `option "Watching" selected: true`, inside a named listbox, with `multiselectable: false`
  computed exactly as in react-aria. VoiceOver reads the attribute (unselected rows announce
  "not selected") but voices nothing in the positive case, on open *and* on arrival by
  navigation. Removing float-kit's `dialog` wrapper made our tree structurally identical to an
  implementation that does voice it, and changed nothing audible. Stop proposing attribute changes
  on the option or the listbox **as a way to make the positive state audible** — that is the half
  that is not ours to fix. The parenthetical above is the other half and is still open: unselected
  rows announce "not selected" because we emit the attribute on every option, and quietening that
  is an attribute change worth making. See deferred cycle 3.

  Our input-based typeahead is silent in the positive case too, so the controller element is not
  the difference either. **Closed by reading the reference implementation:** react-aria announces
  it artificially. `useComboBox` carries `// Announce when a selection occurs for VoiceOver.
  Other screen readers typically do this automatically.` and pushes an announcement through a
  live region, gated on `isAppleDevice()`; its `focusAnnouncement` does the same on every cursor
  move, bundling the option text with its selected state. That is the double reading a listener
  hears. So VoiceOver genuinely does not voice this state, our markup is correct, and the only
  remedy is an announcement — see the deferred cycle.
- **The entry collision has a twin on the filter path, and it needed three answers, not two.** A
  second VoiceOver pass found the same defect after every query, not just on open: the roving
  modifier resets on the resolved filter, so a query change re-seeds the cursor in the same render
  that fires the count, and the reader heard "2 results" and never the match. Suppressing the count
  there is the entry rule verbatim.

  The first attempt made it a binary — announce the count whenever the cursor did not move — and a
  listen killed it in one keystroke. Narrowing `f` to `fe` keeps the cursor on the same row while
  that row's `aria-setsize` goes from 2 to 1: nothing re-reads it, so the reader heard "1 result"
  and never learned *which* option survived. A count is a strictly weaker answer than the row,
  which reports the match and the new set together. So the middle case gets neither suppression nor
  a count: **ask for the row again**, by dropping `aria-activedescendant` and restoring it a tick
  later (`reannounceActive` on the roving modifier; re-asserting the same value is a no-op nothing
  can observe). The count survives only where nothing about the set changed.

  **The report has to outlast the screen reader's own typing echo.** `reannounceActive` worked on
  the first listen — VoiceOver began reading "Fea…" — and then abandoned it mid-word to speak the
  field contents instead. The echo interrupts anything the page says underneath it, so a report
  fired promptly is started and dropped, which is worse than one that arrives late. Hence 1400ms,
  which is what shipped autocomplete implementations have independently converged on; research
  turned up the same collision reached from the other direction too, as advice not to set
  `aria-activedescendant` immediately after a keystroke. Search terms, since none of this is
  visible from the code: *screen reader typing echo interrupts aria-live*,
  *aria-activedescendant clobbered*. It costs nothing visually — the highlight is a class, and this
  re-points only the ARIA attribute.

  **An unchanged set is not reported.** The original complaint included getting no count for a query
  that changed nothing, so the first build announced it, and a listen killed that: typing `fea` then
  `feat` then backspacing through them produced "1 result" on some keystrokes and silence on others.
  At the time this was diagnosed as an audibility problem — an identical message reaching the region
  only when its clear timer happened to have fired since the same string was last spoken — and the
  silence was justified by it.

  **That justification is dead; the decision survives on a different one.** #42184 idles the regions
  on a non-breaking space, so a repeat is a change between two non-empty strings rather than a
  rewrite to the text already there, and it is spoken reliably. Confirmed by ear on the hero category
  chooser: `feag` and then `feagh` each say "No results found". Identical repeats are dependable now,
  so anyone re-reading the old reason will correctly conclude it no longer applies — and must not
  conclude from that that the unchanged count should come back.

  What was thought to rule it out is the governing rule: the row is still mounted and still carries
  `aria-posinset`/`aria-setsize`, so the answer stays reachable and declining to repeat it destroys
  nothing. For a client-side substring filter that much is exact rather than approximate — typing
  forward can only shrink the match set, so an unchanged count *is* an unchanged set.

  **This is reopened, not settled** (raised on review of the 2026-07-30 listen, and it is a better
  question than the one the original build answered). Silence is not what a sighted reader gets: they
  see the list hold still, continuously and for free, while a screen reader reader gets nothing. The
  typing echo covers only that the character reached the *field*, not that the list re-ran and came
  back the same. Two things the record got wrong and a resuming session should not inherit:

  - **The chattiness objection predates the coalescing.** The erratic "1 result" was per-keystroke
    and undebounced. A report now fires once per *settled* query on `RESULT_REPORT_DELAY`, so a
    reader typing fluently produces one, not one per character. Nobody re-tested the objection after
    the delay landed.
  - **The count is the wrong instrument, but it is not the only one.** The dedupe sits upstream of
    the arbitration (`announceCount` returns before `#scheduleReport`), so `#resolvePendingCount`
    never runs for an unchanged count and branch 2 — "new query, cursor did not move, re-read the
    row" — never gets its chance. Moving the dedupe down into branch 3, where it would suppress only
    the count *utterance*, makes an unchanged set re-read the row instead of saying nothing: the
    channel that carries the match and the set together, through `reannounceActive`, which is already
    confirmed by ear. Cost: every settled no-op query re-reads the row. Whether that is useful or
    naggy is a listen, not an argument, and it is a new audible behaviour, so it wants its own cycle.

  **The count dedupes, the empty does not, and the asymmetry is the rule rather than an oversight.**
  One keystroke apart the same region takes opposite policies — `announceCount` returns early on a
  repeated message, `announceNoResults` deliberately does not. An empty set has no row to carry the
  answer and nothing to arrow to, so the region is the only channel it has; a non-empty unchanged set
  already has one. Do not reconcile them by aligning them.

  **The dedupe keys on the message, not on the set, and that was checked rather than assumed.** Two
  different sets of equal size collide. Unreachable on the client path by the subset argument above.
  Reachable from a server source, but there the cursor lands on a different item, `activeOptionKey`
  changes, and the platform reads the new row unprompted — the same outcome the cursor-moved branch
  would have produced. In the residual case where the active row survives while its neighbours churn,
  the count is identical by construction and would say nothing about what changed.

  **The empty report is preempted by the reader re-introducing the combobox.** "No results found"
  arrived only sometimes, and a listen caught what preempted it: "you are currently on a
  combobox…". Emptying the list destroys the element `aria-controls` names (`activeListboxId` drops
  the id only below min-chars, never for an empty result), and the roving cleanup strips
  `aria-activedescendant` — so the control momentarily references nothing, and the reader answers
  that by describing the whole control again. Same remedy as the typing echo: hold the report for
  `RESULT_REPORT_DELAY`.

  **The dangling reference itself is still there**, and it is the underlying defect rather than the
  announcement timing. Two ways out, and picking one is a structural decision: keep a
  `role="listbox"` element mounted with the id when the set is empty (an empty listbox is valid, and
  the status message would sit beside it rather than inside), or treat an absent popup as a closed
  one and flip `aria-expanded` — which reads correctly but changes what "open" means while a panel
  is visible on screen. Not attempted here.

  One mechanical finding came out of the same work: the count announcement was keyed only on
  `items.length`/`engine.total`, so a query change alone never called it — the resolved filter is
  now an argument, which is what lets the row-re-read case be recognised at all.
- **Arrow-down "skipping" the first result is not a defect.** The cursor is already on row one, so
  moving to row two is correct. The reader had simply never heard row one. Do not add an
  off-by-one to compensate.
- **The panel role is decided by whether the panel owns a controller, not by variant.** Dropping
  the `dialog` wrapper started as a K3 experiment on the select-only variant and was kept for
  correctness after it changed nothing audible. It was then scoped to that one variant on a
  justification that does not hold: a typeahead keeps its query input in the *trigger*, so its
  panel holds nothing but the list either, and nothing on that trigger promises a dialog
  (`triggerRootHasPopup` is undefined there). `panelContentRole` now reads
  `isPanelSearchable ? "dialog" : "none"`, which is the actual criterion. Only the searchable
  panel is a composite surface. Expect no audible change from this — K3 is closed above.
- **`aria-multiselectable` is not the K3 difference.** A working combobox (react-aria) reads
  "selected" where ours does not, and its Chrome accessibility tree shows
  `multiselectable: false`, which looks like the missing attribute. It is not: `useListBox`
  emits the attribute only for multiple selection, exactly as we do, so the tree was showing a
  computed default — as the neighbouring `required: false` should have suggested. Do not add it.
- **K1's original premise was wrong.** `aria-expanded` and `aria-haspopup` were already
  emitted. The real defect was `aria-label` on the trigger replacing name-from-contents, so a
  chosen value went unspoken. Fixed separately via `label_with_value`.

## Tests that encoded the bug

Four assertions asserted a count announced at listbox **entry**. Under the rule above the set
size reaches the reader through the seeded row instead, so they were rewritten to assert
`aria-posinset` / `aria-setsize` on the seeded row rather than the message. Same guarantee,
moved to the channel that demonstrably arrives. Two of them also needed the assertion moved
*above* the click that captures the engine, since that click closes the list and takes the
cursor with it.

One test (`d-select-virtual-list-test.gjs`) walked four arrow presses expecting the first to
land on row one — that is, it encoded "opening leaves no cursor". Its subject is header
skipping, so it keeps the same expected sequence and now reads the seeded cursor first.

`d-select-reveal-test.gjs`'s "a new query is not announced as loading more results" closed on the
settled query announcing "7 results". Its query keeps the cursor on the first row, so that report
now arrives as the row's own `aria-setsize`. Its actual subject — that retained rows are never
announced as the new count mid-flight — is untouched.

A fifth (`d-select-multi-flip-test.gjs`) asserted that a post-add filter announces its count,
which the filter-path rule now suppresses on purpose. Re-derived onto a query matching nothing,
whose announcement is unconditional. Investigating it turned up a pre-existing weakness worth
recording: the test was named for proving the count-suppress flag cannot leak past an add, and it
cannot — simulating a leaked flag leaves it green, because the add re-enters the listbox and
re-entry consumes the flag itself. It is now named for what it observes, that an add never silences
the reader's next query.

## Instrument

A live ARIA readout lives at
`plugins/styleguide/.../molecules/select-aria-probe.gjs`. It records a **timeline** of focus,
key and pointer events interleaved with live-region text mutations, and each entry also goes
to the console. It exists because the candidate causes of an announcement bug are
indistinguishable from the outside: a cursor that never moved, a cursor pointing at an id that
does not resolve, state exposed but never voiced, and a message the channel declined to
deliver.

Fields worth knowing about: `barriers` walks from the option to the document reporting
`role=dialog` / `aria-modal` / `aria-hidden` / `inert` / `popover`; `containment` reports
whether the option is a DOM descendant of the controller or merely claimed via
`aria-owns`/`aria-controls`; `cursors agree` compares the visual cursor against the ARIA one.

Two traps it fell into, both fixed, both worth not repeating: it attached its
`MutationObserver` once in the constructor, but the shared live regions render at the *end* of
the application template, after the route subtree, so on a cold load it attached to nothing and
reported a silence indistinguishable from a component that never announced. It now rescans and
reports how many regions it is watching. A **Test channel** button pushes a known message
through the service to tell instrument failure from component silence.

**Intended home:** a dev-tool, once [#41891](https://github.com/discourse/discourse/pull/41891)
lands (`api.devToolsToolbar` plus the `DDockPanel` primitive). The live-region timeline is not
select-specific — chat, topic tracking and the AI plugin all announce through the same service.
The port needs the visual-cursor field generalised off `.d-combobox__option.--active`, and the
container role read rather than assumed to be `listbox`.

The probe no longer renders on the styleguide select page: in the system-spec environment its
styles do not apply, so it rendered as full-width in-flow content that pushed every example
below the fold. The component file stays until the dev-tool port lands — to use it, render
`<SelectAriaProbe />` locally in `molecules/select.gjs`. Note the page's system specs run
against the current source either way; `d_select_cursor_source_spec` turned out to be red from
a stale `-1` expectation predating the set-size fix, not from the probe.

## Known flake

Two tests in `DSelect grouping`, both timing rather than order — the second one failed in a
directory run and then passed under the *identical* seed and test set, which rules order out
directly. `keyboard navigation steps through options and never lands on a header` read an
`aria-activedescendant` that was not an option; same module, same asynchrony as below.

`DSelect grouping: options carry contiguous logical indices and absolute positions across
headers` failed once with **zero** options rendered, then passed under the same seed, so it is
timing rather than order. Its module runs with virtualization enabled, and the assertion reads
mounted rows immediately after opening, so the likely cause is the same asynchrony the open-time
seed fix is about: a windowed list publishes its rows a frame after the listbox exists. Worth
fixing by waiting on a published row rather than by retrying, since a retry would hide exactly
the race the suite is otherwise blind to.

## Deferred to their own planning cycles

1. **Printable-character type-to-jump** on the select-only variant. VoiceOver announces "type
   text" because `role="combobox"` implies it, and APG specifies type-to-jump for the
   select-only pattern, but neither `handleTriggerRootKeydown` nor `dRovingFocus` handles
   printable characters in either state. Needs decisions on buffer timeout, same-letter
   cycling, `Space` semantics while a buffer is non-empty, and whether typing opens a closed
   list. Native `<select>` is the reference.
2. **`@clearable` defaults.** Erasing the query is defined as filtering and never deselects, so
   a control without `@clearable` has no path to an empty value. Before changing any default,
   map what select-kit does per component and what native `<select>` does; they will likely
   disagree, and that disagreement is the decision.
3. **Announcing selection state where VoiceOver will not.** Settled above: the state is exposed
   correctly and VoiceOver ignores it, so conveying it needs a live region. The reference
   implementation gates this on `isAppleDevice()` because other screen readers announce it
   automatically — which matters here more than usual, since the report that started this cycle
   came from NVDA. An unguarded announcement would fix one reader by making another hear it
   twice, so the cycle has to decide what to key the behaviour on, and whether narrating every
   cursor move is acceptable when the same channel is already carrying counts and reveals.

   **Start with the cheap half: stop saying "not selected" on every row.** K3 has two halves, and
   only the silent one is a platform gap. The noisy one is ours — `select-item.gts` emits
   `aria-selected` on every option in every variant (`booleanString … omitFalse=false`, which
   forces the attribute even when false), so arrowing a single-select narrates "not selected" row
   after row for a state that cannot be true of more than one of them. Dropping it for
   single-select variants is one argument, and it may be the whole remaining win in K3.

   It is deferred rather than done because the spec family contradicts itself and no citation
   settles it. APG's own single-select examples emit **only** `aria-selected="true"` and omit the
   attribute elsewhere, and a request to add `false` to the scrollable listbox example was closed
   *wontfix* ([w3c/aria-practices#3175](https://github.com/w3c/aria-practices/issues/3175)). But
   the Listbox pattern prose says every selectable-but-unselected option carries `false`, and the
   ARIA spec's own value semantics back the prose — `undefined` means *not selectable*, so omitting
   it on a selectable option asserts something untrue. Pick a side deliberately, with a listen, and
   note that this also changes what the live-region half of the cycle has to compensate for.

   Re-examine the entry-count suppression at the same time. It was justified by an experiment
   where VoiceOver clearly dropped one of two simultaneous announcements, but react-aria
   announces the count on open *even with a focused item* on Apple devices, on the grounds that
   VoiceOver's row announcement omits it. Both cannot be simply true; the difference may be that
   their announcements are serialised through a single announcer.

   The cycle inherits one more thing: **the "no change" signal, if anyone still wants it.** Note that
   the reason it was originally cut — that an identical live-region message is audible only by
   accident of timing — no longer holds, since #42184 makes repeats dependable. It stays cut on the
   governing rule instead: the row is mounted and carries the whole answer, so the signal would
   restate reachable state rather than report an event. A cycle that wants to reopen it is arguing
   with the rule, not with the platform, and should say which reader asked and for what.
4. **A multi-select `button` trigger that shows no chips.** Today the trigger's content is one
   branch chain testing `@multiple` first, so chips are unconditional for a multi-select and
   `@iconOnly` is unreachable there. Reordering the branches or adding an argument is the small
   part. The design work is that the chips carry three things at once, and dropping them drops
   all three: the trigger's accessible name (with no visible selection text, the name must be
   composed deliberately — the K1 trap, where an author-supplied `aria-label` replaced
   name-from-contents and the value went unspoken), the only removal path outside the panel
   (each chip's remove button is a roving tab stop), and the roving group with its arrow hint.
   The likely shape is a count summary in the trigger with removal living inside the panel,
   which is a different control from a chips field rather than a display toggle on the same one.

   **This may change how K4 is solved.** Tag chips are unreadable because they sit inside a
   `role="button"` trigger, which is children-presentational and prunes them. A button
   multi-select that puts no chips in the trigger sidesteps that without the roleless-wrapper
   restructure proposed below. Settle this cycle before committing to that one.

## Fixed in the unified grouping rework

- **The create row no longer inherits the last group.** `#describeList` used to leave
  `currentGroupOrdinal` set when it reached the appended create row, so "Create 'foo'" carried
  the last group's `aria-describedby` and a reader heard it announced as a member of that group.
  The create row now stamps `groupOrdinal: undefined` and carries no group description.
- **Group `aria-describedby` no longer dangles under windowing.** The header `<li>` used to own
  the group id, and the windowed list unmounts a header row while its options are still visible —
  the reference then named a nonexistent element and the group context silently vanished. Each
  header now contains the id-bearing label span, and the window extension pins that header while
  any row from its group is mounted. Every published window therefore keeps each mounted option's
  description resolvable while keeping the description DOM bounded by the window. A custom group
  header renders beside a hidden label-only span, so its arbitrary markup never enters option
  descriptions.
  This is distinct from the **still-open** `aria-controls` dangling reference above (the empty
  result set destroying the element the combobox names): same defect class, different reference,
  and that one still needs its structural decision.

## Still open

- **K3** — whether a held row now announces "selected". The seed fix may already have resolved
  it; needs one listen on the notification dropdown (which has a value).
- **K1's second half: a pre-selected query is not announced.** Focusing a typeahead that holds a
  value runs `element.select()` (`combobox-query-input.gts`), so the text is selected and ready
  to overtype, and VoiceOver reads the value without reporting the selection — the same class as
  K3, a state the platform declines to voice. The input carries no accessible description today.

  Unlike K3 this has an answer inside the rule: what a reader needs is not "the text is
  selected" but "typing replaces what is there", and a consequence can be *expressed* as an
  accessible description rather than announced. Constraints for the cycle: a description is read
  on every focus, so it must be present only when there is a value that will actually be
  replaced; and it reaches every screen reader rather than only the one with the gap, so it needs
  no UA gate but does add a phrase for readers who did not need it.
- **`filter_to_narrow`** — see the inventory above.
- **K4** — tag chips are pruned by `role="button"` (children-presentational), and the chip
  roving, `tabindex` seeding and the arrow hint are all gated on `isDesktopTypeahead`, which
  that role turns off. The tags showcase does use `@variant="button"` with `@multiple`, so it
  is live. Two candidate resolutions, and they should not be pursued in parallel: a roleless
  wrapper holding the chip list beside a dedicated disclosure button (plus a decision about
  which element `DMenu` registers and restores focus to), or the no-chips button trigger in
  deferred cycle 3, which removes the pruned subtree instead of restructuring around it.
- **A3 (count debounce) — resolved, and it earned its place for a different reason than planned.**
  Not for rate-limiting a chatty channel, but because keying the count on the query means a client
  source (un-debounced by design) would otherwise report the count on every keystroke once the
  results stop moving. 1400ms — the value the typing-echo listen forced, not the 300ms a pure
  debounce would want — and the same timer is what defers the announce/suppress decision until the
  cursor has settled.

  **Two parts of it are invisible to the suite**, so they rest on the listen and on review: the
  coalescing itself, and the cancel-on-close. Every `await` in a rendering test drains the runloop
  timer, so a pending count cannot survive across a close and a test asserting that would be
  vacuous rather than protective. The cancels live in `#releaseAnnouncementSession` and
  `willDestroy`.
- **`reannounceActive` works, confirmed by ear**, and it needed the long delay to survive the
  typing echo. Verified against VoiceOver on the hero category chooser: `f` reads "feature
  requests, 1 of 2", `fe` reads "feature requests, 1 of 1", and backspacing back to `f` reads
  "1 of 2" again. Unlike the service's blank-and-restore for text — which VoiceOver ignores —
  re-pointing the cursor does get read.

  A recovery affordance for a row the platform drops (a key that re-reads the active row on demand)
  was deliberately not built, but `reannounceActive` is now the mechanism it would use, so it is a
  keybinding away and can be decided on evidence.
- **K7 — Safari reads an unknown set size as 18446744073709551615.** Heard on the "Paginated server
  source" styleguide example. That number is 2^64 − 1: WebKit coerces a negative `aria-setsize` to
  unsigned instead of treating it as the unknown-size sentinel, so every row announces "N of
  18446744073709551615". Predates this cycle and is unrelated to the filter-path work — the spike
  under discussion neither caused it nor touches it.

  `#describeList` emits real `aria-posinset` on loaded rows and `setSize` of `-1` while
  `sourceTotal == null` (`select-engine.ts:1339`). A server source is incomplete for its whole
  paging life (`knownComplete()` is `serverComplete && !serverTruncated`), and the fixture pages 50
  at a time through 5000, so on that example the condition is the normal state rather than an edge
  case. Two tests encode it deliberately: the partially-loaded response and the cursor source's
  unknown size.

  **This is not "correct markup defeated by one buggy browser", which is how it first looked.** The
  first reading of this finding was that ARIA blesses `-1` and WebKit is wrong, so the fix belongs
  upstream. Checking the sources reversed it, and a resuming session should not re-derive the
  comfortable version:

  - **The spec contradicts itself.** ARIA: authors SHOULD set `-1` when the total is unknown.
    Core-AAM: user agents SHOULD use `1` instead for negative values. HTML-AAM implies the value
    should instead be computed from the DOM. Mutually incompatible, and open as
    [w3c/aria#2346](https://github.com/w3c/aria/issues/2346).
  - **No engine implements `-1` usefully, and each fails differently**
    ([w3c/core-aam#149](https://github.com/w3c/core-aam/issues/149)): Chromium reports the highest
    `aria-posinset` present in the DOM and grows it as rows load; Gecko counts only DOM rows, giving
    "68 of 10"; WebKit announces the raw `-1`, which is the number heard here.
  - **The WG is moving to retract the authoring requirement.**
    [w3c/aria#1759](https://github.com/w3c/aria/issues/1759) proposes SHOULD → MAY or deleting the
    `-1` guidance outright, citing "row 1 of 0". Open, PR #2341 attached.
  - **WebKit #246426 does not obviously fix the speech.**
    [Commit ca1977f](https://github.com/WebKit/WebKit/commit/ca1977fd4ef6781d33ab200c61f446550f7c6fdb)
    moves `aria-setsize` onto the list container and adds a `-1` test, but the test asserts the value
    is *exposed* through `AXARIASetSize`, not that VoiceOver stops speaking it. Do not treat this as
    "fixed upstream, wait it out".

  So `-1` is an authoring requirement with no working implementation in any engine, contradicted by
  its own AAM, and possibly on its way out. Emitting it is the thing to reconsider. Options, with the
  costs restated now that the engine behaviour is known rather than guessed:

  - **Report the loaded count while incomplete.** "50 of 50" at a page boundary can read as end of
    list. Initially recorded here as strictly worse than the status quo; that was an overstatement.
    It assumed no other signal, but the count channel already narrates `loading_more` and
    `results_loaded`, which is exactly the mitigation, and it is also what Chromium already does on
    its own when told `-1`. It has the further virtue of making all three engines agree.
  - **Omit `aria-setsize` alone.** Lands on the DOM-count fallback, which is Gecko's "68 of 10" —
    confirmed bad by the core-aam issue rather than predicted.
  - **Omit both `aria-posinset` and `aria-setsize` while unknown.** No number to garble, and the
    loading state stays on the channel that can express "still growing". Costs the reader positional
    feedback while paging, and needs a listen to confirm the engines do not simply DOM-count anyway.

  Whichever is chosen, decide it with a listen on the paginated example, and record which engines
  were checked.

  **The bigger half turned out not to need a sentinel at all.** Reaching for a replacement for `-1`
  skipped the prior question of whether the value was ever unknown. It usually is not: the server
  source reports `serverTotal` *precisely while it is incomplete* (`total()` returns the loaded
  count only once complete), and the paginated fixture declares `total` on every page. So the engine
  held a real 5000 and published "unknown", because `#describeList` gated the total on
  `knownComplete` as well as on its presence. Dropping that gate is the fix; the `Math.max(total,
  sourceCount)` floor beside it — not completeness — is what actually guards a transformer pushing a
  position past the set. Red/green captured by re-deriving the partially-loaded test, which had
  encoded the discard as intended behaviour ("cannot honestly size its set"). Only a source with no
  total at all now reaches `-1`, which shrinks the open question to the "more-ness" example.

  **The total-less half then went the same way**: sized by the rows loaded so far, never `-1`. The
  loaded rows are the ones the reader can actually reach — windowing is a DOM concern and the roving
  cursor navigates logical indices — so the number is honest about the set it describes, all three
  engines agree on it, and it is what Chromium already synthesizes from `-1` anyway. Its cost is a
  page boundary that reads as an ending ("3 of 3"); the reader who arrows on is corrected to "4 of
  5" immediately, and `loading_more` / `results_loaded` / the busy state carry the "more exists" half
  that a single integer cannot. Falling out of that, the create row now closes the set instead of
  dropping its position, since an appended row *does* have a derivable slot once the set is sized.

  Four tests encoded `-1` as intended behaviour and were re-derived: the partially-loaded response,
  the cursor source mid-paging, the create row, and one secondary assertion inside the
  completion-announcement test. That last one is worth preserving as written — it now asserts the
  row is sized 3 while the *announcement* on completion still reports the true 5, because the set
  metadata and the count channel answer different questions and only one of them knows the total.

  **Still open**: the truncation interaction. A `serverTruncated` source reports a total whose tail
  `MAX_RENDERED` will never render, so the size describes a complete set the reader cannot walk to
  the end of. Spec-literal says `aria-setsize` is the complete set; the reachable-set reading
  disagrees. Untested either way — do not assume the current behaviour there is deliberate.
- **A skipped row still occupies a position.** On the notification picker VoiceOver reads
  "Watching, 4 of 6", and one ArrowDown lands on "Manage notification settings, 6 of 6" — the
  reader hears a position vanish and reasonably concludes the list misbehaved. The set size is
  wrong for two independent reasons, and `#isStructural`
  (`select-engine.ts`) is the common cause: it treats only headers and dividers as
  non-options, so both of these are counted.
  1. **A disabled row is counted but unreachable.** `dRovingFocus`'s `#isUsable` skips
     `aria-disabled="true"`, so the position exists and nothing can land on it.
  2. **An action row is counted as a choice.** A row carrying `onSelect` is a command, not a
     value, yet it occupies the last position — so the size claims one more choice than exists.

  The fork on (1): hide the disabled row from the set, or make it navigable and announce it as
  unavailable. Prefer **navigable**. Hiding it removes the row from the accessibility tree while
  leaving it on screen, so a reader cannot learn that an option they can see exists — and when a
  row is disabled conditionally, its existence is the actionable part. Renumbering to cover only
  navigable rows is coherent but produces the same blind spot. Note the costs before committing:
  `#isUsable` is shared with focus mode and mirrors `d-tab-to-sibling`, so this reaches past
  select, and native `<select>` does skip disabled options — check what browsers actually report
  for `aria-posinset` there rather than assuming native is the reference.

  (2) is a separate decision about the action-row API, not a numbering fix: a command in the
  option set is arguably in the wrong place entirely, and the footer slot already exists for
  controls that are not choices.
- **C3** — the active-option outline and the trigger focus ring were both
  `2px solid var(--tertiary)`, so active-descendant mode read as two focused things. A dashed
  treatment was tried and reverted as an unrequested design invention; the differentiation is
  the design review's call.

## Dependency

The branch is stacked on
[#42120](https://github.com/discourse/discourse/pull/42120) (`a11y` service repeat delivery).
That PR makes a repeated identical message audible by blanking the region and restoring it a
tick later; without it, whether a repeat was heard depended on how long ago the same string was
last spoken. Merging that PR's mechanism with this branch's same-flush composition required one
rule: a buffered message that only restates what the region already shows is dropped when the
flush carries something else, so a superseded count is not read aloud ahead of the current one.
