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
| K1 | No way to tell you can type in the combobox, or that existing text is highlighted | ◐ trigger naming shipped; typing ⊘ |
| K2 | Results not announced as results; "no results" never spoken; inconsistent re-announcement | ☑ |
| K3 | "selected" not announced when navigating, but "not selected" is | ☐ needs a re-listen |
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
| Count on update while open | Keep. The set changed and nothing else says so. |
| `no_results`, `min_chars` | Keep. They fire only when there are no rows, so no cursor exists to compete with, and the platform cannot say "your query matched nothing". |
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
3. **A multi-select `button` trigger that shows no chips.** Today the trigger's content is one
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

## Still open

- **K3** — whether a held row now announces "selected". The seed fix may already have resolved
  it; needs one listen on the notification dropdown (which has a value).
- **`filter_to_narrow`** — see the inventory above.
- **K4** — tag chips are pruned by `role="button"` (children-presentational), and the chip
  roving, `tabindex` seeding and the arrow hint are all gated on `isDesktopTypeahead`, which
  that role turns off. The tags showcase does use `@variant="button"` with `@multiple`, so it
  is live. Two candidate resolutions, and they should not be pursued in parallel: a roleless
  wrapper holding the chip list beside a dedicated disclosure button (plus a decision about
  which element `DMenu` registers and restores focus to), or the no-chips button trigger in
  deferred cycle 3, which removes the pruned subtree instead of restructuring around it.
- **A3 (count debounce)** — re-derive whether it is still needed. Much of what made
  re-announcement feel erratic was the entry count and the service swallowing identical
  repeats; both are addressed.
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
